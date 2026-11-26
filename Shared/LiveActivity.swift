import Foundation
import ActivityKit

struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var projectName: String
        var task: String?
        var startedAt: Date
    }
}

/// Keeps a single Live Activity in sync with the running entry.
/// Only does anything in the app process; the widget extension never starts activities.
@MainActor
enum LiveActivityController {
    #if !WIDGET_EXTENSION
    /// The previous sync, so syncs run one after another in call order. Otherwise
    /// two quick changes (e.g. stop + start) could finish out of order and leave
    /// the activity showing the older state.
    private static var lastSync: Task<Void, Never>?
    #endif

    static func sync(running: Entry?) {
        #if !WIDGET_EXTENSION
        // Capture the state now, on the main actor, while `running` is current.
        let content: ActivityContent<TimerActivityAttributes.ContentState>? = running.flatMap { running in
            guard let name = running.project?.name else { return nil }
            let state = TimerActivityAttributes.ContentState(
                projectName: name, task: running.task, startedAt: running.from)
            return ActivityContent(state: state, staleDate: running.autoStopDate)
        }
        let previous = lastSync
        lastSync = Task {
            await previous?.value
            await apply(content)
        }
        #endif
    }

    #if !WIDGET_EXTENSION
    private static func apply(_ content: ActivityContent<TimerActivityAttributes.ContentState>?) async {
        let activities = Activity<TimerActivityAttributes>.activities
        // An activity the system ended (Live Activities last at most ~8 hours) or the
        // user dismissed can linger in the list and on the Lock Screen, but updates
        // to it are ignored. Remove those and only reuse a live one.
        let live = activities.filter { $0.activityState == .active || $0.activityState == .stale }
        for activity in activities where !live.contains(where: { $0.id == activity.id }) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        guard let content else {
            for activity in live { await activity.end(nil, dismissalPolicy: .immediate) }
            return
        }

        if let current = live.first {
            for extra in live.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
            await current.update(content)
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity.request(attributes: TimerActivityAttributes(), content: content, pushType: nil)
        }
    }
    #endif
}

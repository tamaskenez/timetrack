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
    static func sync(running: Entry?) {
        #if !WIDGET_EXTENSION
        let activities = Activity<TimerActivityAttributes>.activities

        guard let running, let name = running.project?.name else {
            for activity in activities {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }

        let state = TimerActivityAttributes.ContentState(
            projectName: name, task: running.task, startedAt: running.from)
        let content = ActivityContent(state: state, staleDate: running.autoStopDate)

        if let current = activities.first {
            for extra in activities.dropFirst() {
                Task { await extra.end(nil, dismissalPolicy: .immediate) }
            }
            Task { await current.update(content) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity.request(attributes: TimerActivityAttributes(), content: content, pushType: nil)
        }
        #endif
    }
}

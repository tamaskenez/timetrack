import Foundation
import SwiftData
import WidgetKit

/// All timer state changes go through here so the "one running entry" rule,
/// the widget and the Live Activity stay consistent.
@MainActor
enum TimerService {
    static func runningEntries(_ context: ModelContext) -> [Entry] {
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.until == nil })
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Starts tracking `project`, stopping any running entry at the same instant.
    static func start(_ project: Project, task: String? = nil, at date: Date = .now, context: ModelContext) {
        for entry in runningEntries(context) {
            entry.until = clampedEnd(date, for: entry)
        }
        context.insert(Entry(from: date, until: nil, project: project, task: task?.normalizedTask))
        didChange(context)
    }

    /// Stops the running entry. `date` is clamped to the start and the auto-stop time.
    static func stop(at date: Date = .now, context: ModelContext) {
        for entry in runningEntries(context) {
            entry.until = clampedEnd(date, for: entry)
        }
        didChange(context)
    }

    private static func clampedEnd(_ date: Date, for entry: Entry) -> Date {
        min(max(date, entry.from), entry.autoStopDate)
    }

    /// Stops running entries that reached the maximum duration.
    static func applyAutoStop(_ context: ModelContext, now: Date = .now) {
        for entry in runningEntries(context) where now >= entry.autoStopDate {
            entry.until = entry.autoStopDate
        }
    }

    /// Saves and refreshes everything that mirrors the data outside the app.
    /// Also applies the auto-stop, so it runs whenever the app becomes active.
    static func didChange(_ context: ModelContext) {
        applyAutoStop(context)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        LiveActivityController.sync(running: runningEntries(context).first)
    }

    /// Tasks previously used on `project`, most recent first, matching `text`.
    static func taskSuggestions(for project: Project?, matching text: String, limit: Int = 6) -> [String] {
        guard let project else { return [] }
        let query = text.trimmingCharacters(in: .whitespaces)
        var seen = Set<String>()
        var result: [String] = []
        for entry in (project.entries ?? []).sorted(by: { $0.from > $1.from }) {
            guard let task = entry.task, !seen.contains(task.lowercased()) else { continue }
            seen.insert(task.lowercased())
            if task.caseInsensitiveCompare(query) == .orderedSame { continue }
            if query.isEmpty || task.localizedCaseInsensitiveContains(query) {
                result.append(task)
                if result.count == limit { break }
            }
        }
        return result
    }
}

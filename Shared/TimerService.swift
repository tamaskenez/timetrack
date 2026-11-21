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
            entry.until = max(date, entry.from)
        }
        context.insert(Entry(from: date, until: nil, project: project, task: task?.normalizedTask))
        didChange(context)
    }

    /// Stops the running entry. `date` is clamped to not precede the start.
    static func stop(at date: Date = .now, context: ModelContext) {
        for entry in runningEntries(context) {
            entry.until = max(date, entry.from)
        }
        didChange(context)
    }

    /// Saves and refreshes everything that mirrors the data outside the app.
    static func didChange(_ context: ModelContext) {
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

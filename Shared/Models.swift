import Foundation
import SwiftData

// All properties have defaults or are optional and relationships are optional,
// so the schema stays compatible with CloudKit sync if it's enabled later.

@Model
final class Project {
    var name: String = ""
    var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \Entry.project)
    var entries: [Entry]? = []

    init(name: String, sortOrder: Int) {
        self.name = name
        self.sortOrder = sortOrder
    }
}

@Model
final class Entry {
    var from: Date = Date()
    /// `nil` while the timer is running.
    var until: Date?
    var project: Project?
    var task: String?

    init(from: Date, until: Date?, project: Project?, task: String?) {
        self.from = from
        self.until = until
        self.project = project
        self.task = task
    }

    var isRunning: Bool { until == nil }

    /// When a running entry is stopped automatically.
    var autoStopDate: Date { from.addingTimeInterval(TimeMath.maxEntryDuration) }

    /// End of the entry; for a running entry `now`, capped at the auto-stop time.
    func end(now: Date = .now) -> Date { until ?? min(now, autoStopDate) }

    func duration(now: Date = .now) -> TimeInterval {
        max(0, end(now: now).timeIntervalSince(from))
    }
}

extension String {
    /// Trimmed task text, or `nil` if empty.
    var normalizedTask: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

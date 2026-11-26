import Foundation

enum TimeMath {
    /// Calendar with weeks starting on Monday.
    static var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    static func today(now: Date = .now) -> DateInterval {
        calendar.dateInterval(of: .day, for: now)!
    }

    /// A running timer is stopped automatically after this long, so an entry
    /// never spans more than two calendar days.
    static let maxEntryDuration: TimeInterval = 24 * 3600

    /// The day an entry belongs to: the day it ends (today for a running entry).
    /// An entry ending exactly at midnight belongs to the day before.
    static func day(of entry: Entry, now: Date = .now) -> Date {
        let end = entry.end(now: now)
        let anchor = end > entry.from ? end.addingTimeInterval(-0.001) : end
        return calendar.startOfDay(for: anchor)
    }

    /// Whether `entry`'s day (see `day(of:)`) falls inside `interval`.
    static func belongs(_ entry: Entry, to interval: DateInterval, now: Date = .now) -> Bool {
        let d = day(of: entry, now: now)
        return d >= interval.start && d < interval.end
    }

    /// Full duration of the entries whose day falls inside `interval`.
    static func total(_ entries: [Entry], in interval: DateInterval, now: Date = .now) -> TimeInterval {
        entries.filter { belongs($0, to: interval, now: now) }.reduce(0) { $0 + $1.duration(now: now) }
    }

    /// Half-open overlap test: touching ranges (one ends when the next starts) don't overlap.
    static func overlaps(_ aStart: Date, _ aEnd: Date, _ bStart: Date, _ bEnd: Date) -> Bool {
        aStart < bEnd && bStart < aEnd
    }

    /// Whole minutes, rounded to the nearest (30s rounds up). Durations are
    /// stored and summed unrounded; rounding happens only here, for display.
    static func roundedMinutes(_ interval: TimeInterval) -> Int {
        Int((interval / 60).rounded())
    }

    /// "1h 23m", "45m", "0m". Rounded to the nearest minute.
    static func format(_ interval: TimeInterval) -> String {
        let minutes = roundedMinutes(interval)
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    /// "1:05", "0:45", "12:00". Rounded to the nearest minute.
    static func formatHM(_ interval: TimeInterval) -> String {
        let minutes = roundedMinutes(interval)
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

extension TimeMath {
    /// What saving an entry `[from, until)` does to another entry `[otherFrom, otherEnd)`
    /// that overlaps it: the saved entry wins and the other gives way.
    enum OverlapResolution: Equatable {
        /// Fully covered: the other entry is deleted.
        case delete
        /// Starts before: the other entry now ends at `from`.
        case trimEnd(Date)
        /// Ends after: the other entry now starts at `until`.
        case trimStart(Date)
        /// Covers the saved entry on both sides: the part before stays,
        /// the part after becomes a new entry.
        case split(Date, Date)
    }

    static func overlapResolution(from: Date, until: Date, otherFrom: Date, otherEnd: Date) -> OverlapResolution {
        let before = otherFrom < from
        let after = otherEnd > until
        switch (before, after) {
        case (false, false): return .delete
        case (true, false): return .trimEnd(from)
        case (false, true): return .trimStart(until)
        case (true, true): return .split(from, until)
        }
    }
}

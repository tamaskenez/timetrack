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

    /// "1h 23m", "45m", "0m".
    static func format(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    /// "1:05", "0:45", "12:00".
    static func formatHM(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

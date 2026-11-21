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

    /// Duration of `entry` that falls inside `interval`.
    static func duration(of entry: Entry, in interval: DateInterval, now: Date = .now) -> TimeInterval {
        let start = max(entry.from, interval.start)
        let end = min(entry.end(now: now), interval.end)
        return max(0, end.timeIntervalSince(start))
    }

    static func total(_ entries: [Entry], in interval: DateInterval, now: Date = .now) -> TimeInterval {
        entries.reduce(0) { $0 + duration(of: $1, in: interval, now: now) }
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
}

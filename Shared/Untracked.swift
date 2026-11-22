import Foundation

extension TimeMath {
    /// One entry reduced to what the untracked calculation needs.
    struct Span {
        var from: Date
        var end: Date
        /// The day the entry belongs to (`TimeMath.day(of:)`): start of the day it ends.
        var day: Date
        var duration: TimeInterval { max(0, end.timeIntervalSince(from)) }
    }

    /// Untracked time per day, keyed by the start of the day.
    ///
    /// A day's span starts when its first entry starts (possibly on the previous
    /// calendar day) and ends when its last entry ends, unless the next day's
    /// first entry starts on this day: then it ends when that entry starts.
    /// Untracked time is the span minus the day's tracked total, never negative
    /// (overlapping entries can make the tracked total exceed the span).
    static func untracked(_ spans: [Span], calendar: Calendar = TimeMath.calendar) -> [Date: TimeInterval] {
        let byDay = Dictionary(grouping: spans, by: \.day)
        var result: [Date: TimeInterval] = [:]
        for (day, daySpans) in byDay {
            let start = daySpans.map(\.from).min()!
            var end = daySpans.map(\.end).max()!
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
               let nextFirst = byDay[nextDay]?.map(\.from).min(),
               nextFirst < nextDay {
                end = nextFirst
            }
            let tracked = daySpans.reduce(0) { $0 + $1.duration }
            result[day] = max(0, end.timeIntervalSince(start) - tracked)
        }
        return result
    }
}

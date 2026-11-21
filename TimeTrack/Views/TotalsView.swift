import SwiftUI
import SwiftData

struct TotalsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case today = "Today", week = "This Week", ever = "Ever", days = "Days"
        var id: Self { self }

        /// The period summed by the per-project list (not used by `.days`).
        func interval(now: Date) -> DateInterval {
            switch self {
            case .today: TimeMath.calendar.dateInterval(of: .day, for: now)!
            case .week: TimeMath.calendar.dateInterval(of: .weekOfYear, for: now)!
            case .ever, .days: DateInterval(start: .distantPast, end: .distantFuture)
            }
        }
    }

    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query private var entries: [Entry]
    @State private var mode: Mode = .today

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Period", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                TimelineView(.periodic(from: .now, by: 30)) { timeline in
                    if mode == .days {
                        DaysTable(projects: projects, entries: entries, now: timeline.date)
                    } else {
                        projectList(now: timeline.date)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Totals")
        }
    }

    private func projectList(now: Date) -> some View {
        let interval = mode.interval(now: now)
        let rows = projects.compactMap { project -> ProjectTotal? in
            let projectEntries = entries.filter { $0.project == project }
            var byTask: [String?: TimeInterval] = [:]
            for entry in projectEntries {
                let d = TimeMath.duration(of: entry, in: interval, now: now)
                if d > 0 { byTask[entry.task, default: 0] += d }
            }
            let total = byTask.values.reduce(0, +)
            guard total > 0 else { return nil }
            let tasks = byTask.map { TaskTotal(name: $0.key, duration: $0.value) }
                .sorted { $0.duration > $1.duration }
            return ProjectTotal(name: project.name, total: total, tasks: tasks)
        }
        let grandTotal = rows.reduce(0) { $0 + $1.total }

        return List {
            Section {
                HStack {
                    Text("Total").font(.headline)
                    Spacer()
                    Text(TimeMath.format(grandTotal)).font(.headline).monospacedDigit()
                }
            } header: {
                Text(mode == .ever ? "All time" : Self.describe(interval))
            }

            if !rows.isEmpty {
                Section("Projects") {
                    ForEach(rows) { row in
                        DisclosureGroup {
                            ForEach(row.tasks) { task in
                                HStack {
                                    Text(task.name ?? "No task")
                                        .foregroundStyle(task.name == nil ? Color.secondary : Color.primary)
                                    Spacer()
                                    Text(TimeMath.format(task.duration)).monospacedDigit()
                                }
                                .font(.subheadline)
                            }
                        } label: {
                            HStack {
                                Text(row.name)
                                Spacer()
                                Text(TimeMath.format(row.total)).monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
    }

    private static func describe(_ interval: DateInterval) -> String {
        // DateInterval.end is exclusive; show the last day included.
        let lastDay = interval.end.addingTimeInterval(-1)
        if TimeMath.calendar.isDate(interval.start, inSameDayAs: lastDay) {
            return interval.start.formatted(date: .complete, time: .omitted)
        }
        return "\(interval.start.formatted(date: .abbreviated, time: .omitted)) – \(lastDay.formatted(date: .abbreviated, time: .omitted))"
    }
}

/// Rows are projects, columns are days (newest first). Only days with tracked
/// time are shown; entries spanning midnight are split between the days.
private struct DaysTable: View {
    let projects: [Project]
    let entries: [Entry]
    let now: Date

    private let nameWidth: CGFloat = 110
    private let cellWidth: CGFloat = 60
    private let rowHeight: CGFloat = 36
    private let headerHeight: CGFloat = 44

    var body: some View {
        let calendar = TimeMath.calendar
        // totals[projectID][day]
        var totals: [PersistentIdentifier: [Date: TimeInterval]] = [:]
        var dayTotals: [Date: TimeInterval] = [:]
        for entry in entries {
            guard let project = entry.project else { continue }
            var day = calendar.startOfDay(for: entry.from)
            let end = entry.end(now: now)
            while day < end {
                let interval = calendar.dateInterval(of: .day, for: day)!
                let d = TimeMath.duration(of: entry, in: interval, now: now)
                if d > 0 {
                    totals[project.persistentModelID, default: [:]][day, default: 0] += d
                    dayTotals[day, default: 0] += d
                }
                day = interval.end
            }
        }
        let days = dayTotals.keys.sorted(by: >)
        let rows = projects.filter { totals[$0.persistentModelID] != nil }

        return Group {
            if days.isEmpty {
                ContentUnavailableView("No Entries", systemImage: "tablecells",
                                       description: Text("Tracked time will show up here by day."))
            } else {
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: 0) {
                        // Fixed project name column.
                        VStack(alignment: .leading, spacing: 0) {
                            cell("", width: nameWidth, height: headerHeight)
                            ForEach(rows) { project in
                                cell(project.name, width: nameWidth, height: rowHeight, alignment: .leading)
                            }
                            cell("Total", width: nameWidth, height: rowHeight, alignment: .leading)
                                .fontWeight(.semibold)
                        }
                        .padding(.leading)

                        Divider()

                        ScrollView(.horizontal) {
                            HStack(spacing: 0) {
                                ForEach(days, id: \.self) { day in
                                    VStack(spacing: 0) {
                                        VStack(spacing: 0) {
                                            Text(day.formatted(.dateTime.weekday(.abbreviated)))
                                            Text(day.formatted(.dateTime.day().month(.abbreviated)))
                                                .foregroundStyle(.secondary)
                                        }
                                        .font(.caption)
                                        .frame(width: cellWidth, height: headerHeight)

                                        ForEach(rows) { project in
                                            let d = totals[project.persistentModelID]?[day] ?? 0
                                            durationCell(d)
                                        }
                                        durationCell(dayTotals[day] ?? 0).fontWeight(.semibold)
                                    }
                                }
                            }
                            .padding(.trailing)
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func cell(_ text: String, width: CGFloat, height: CGFloat,
                      alignment: Alignment = .center) -> some View {
        Text(text)
            .lineLimit(1)
            .frame(width: width, height: height, alignment: alignment)
            .overlay(alignment: .bottom) { Divider() }
    }

    private func durationCell(_ d: TimeInterval) -> some View {
        Text(d > 0 ? TimeMath.formatHM(d) : "–")
            .monospacedDigit()
            .foregroundStyle(d > 0 ? Color.primary : Color.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: cellWidth, height: rowHeight)
            .overlay(alignment: .bottom) { Divider() }
    }
}

private struct ProjectTotal: Identifiable {
    let name: String
    let total: TimeInterval
    let tasks: [TaskTotal]
    var id: String { name }
}

private struct TaskTotal: Identifiable {
    let name: String?
    let duration: TimeInterval
    var id: String { name ?? "\u{0}none" }
}

import SwiftUI
import SwiftData

struct TotalsView: View {
    enum Period: String, CaseIterable, Identifiable {
        case today = "Today", week = "This Week", month = "This Month"
        var id: Self { self }

        func interval(now: Date) -> DateInterval {
            let component: Calendar.Component = switch self {
            case .today: .day
            case .week: .weekOfYear
            case .month: .month
            }
            return TimeMath.calendar.dateInterval(of: component, for: now)!
        }
    }

    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query private var entries: [Entry]
    @State private var period: Period = .today

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                content(now: timeline.date)
            }
            .navigationTitle("Totals")
        }
    }

    private func content(now: Date) -> some View {
        let interval = period.interval(now: now)
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
                Picker("Period", selection: $period) {
                    ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text(Self.describe(interval))
            }

            Section {
                HStack {
                    Text("Total").font(.headline)
                    Spacer()
                    Text(TimeMath.format(grandTotal)).font(.headline).monospacedDigit()
                }
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

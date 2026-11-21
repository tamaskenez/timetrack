import SwiftUI
import SwiftData

struct EntriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.from, order: .reverse) private var entries: [Entry]

    @State private var editing: Entry?
    @State private var addingNew = false

    private var days: [(day: Date, entries: [Entry])] {
        // An entry belongs to the day it ends.
        let grouped = Dictionary(grouping: entries) { TimeMath.day(of: $0) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(days, id: \.day) { day in
                    Section {
                        ForEach(day.entries) { entry in
                            Button { editing = entry } label: { EntryRow(entry: entry) }
                                .foregroundStyle(.primary)
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(day.entries[index]) }
                            TimerService.didChange(context)
                        }
                    } header: {
                        HStack {
                            Text(day.day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            Spacer()
                            Text(TimeMath.format(day.entries.reduce(0) { $0 + $1.duration() }))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Entries",
                        systemImage: "clock",
                        description: Text("Start a timer or add an entry with +."))
                }
            }
            .navigationTitle("Entries")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { addingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { entry in
                EntryEditor(entry: entry)
            }
            .sheet(isPresented: $addingNew) {
                EntryEditor(entry: nil)
            }
        }
    }
}

private struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.project?.name ?? "—").font(.headline)
                if let task = entry.task {
                    Text(task).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(timeRange).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if entry.isRunning {
                Text(timerInterval: entry.from...entry.autoStopDate, countsDown: false)
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: 90, alignment: .trailing)
            } else {
                Text(TimeMath.format(entry.duration())).monospacedDigit()
            }
        }
    }

    /// Entries are listed under the day they end, so show the start's date if it's an earlier day.
    private var timeRange: String {
        let startsEarlier = !TimeMath.calendar.isDate(entry.from, inSameDayAs: TimeMath.day(of: entry))
        let startTime = entry.from.formatted(date: .omitted, time: .shortened)
        let start = startsEarlier
            ? "\(entry.from.formatted(.dateTime.weekday(.abbreviated))) \(startTime)"
            : startTime
        let end = entry.until?.formatted(date: .omitted, time: .shortened) ?? "now"
        return "\(start) – \(end)"
    }
}

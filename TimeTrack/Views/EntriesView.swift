import SwiftUI
import SwiftData

struct EntriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.from, order: .reverse) private var entries: [Entry]

    @State private var editing: Entry?
    @State private var addingNew = false

    private var days: [(day: Date, entries: [Entry])] {
        let calendar = TimeMath.calendar
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.from) }
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
                Text(timerInterval: entry.from...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: 90, alignment: .trailing)
            } else {
                Text(TimeMath.format(entry.duration())).monospacedDigit()
            }
        }
    }

    private var timeRange: String {
        let start = entry.from.formatted(date: .omitted, time: .shortened)
        guard let until = entry.until else { return "\(start) – now" }
        let sameDay = TimeMath.calendar.isDate(entry.from, inSameDayAs: until)
        let end = sameDay
            ? until.formatted(date: .omitted, time: .shortened)
            : until.formatted(date: .abbreviated, time: .shortened)
        return "\(start) – \(end)"
    }
}

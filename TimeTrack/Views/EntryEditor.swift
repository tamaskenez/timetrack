import SwiftUI
import SwiftData

/// Add (entry == nil) or edit an entry. Changes apply only on Save.
struct EntryEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query private var allEntries: [Entry]

    let entry: Entry?

    @State private var project: Project?
    @State private var taskText: String
    @State private var from: Date
    @State private var until: Date
    @State private var isRunning: Bool
    @State private var confirmDelete = false

    init(entry: Entry?) {
        self.entry = entry
        let now = Date.now
        _project = State(initialValue: entry?.project)
        _taskText = State(initialValue: entry?.task ?? "")
        _from = State(initialValue: entry?.from ?? now.addingTimeInterval(-3600))
        _until = State(initialValue: entry?.until ?? now)
        _isRunning = State(initialValue: entry?.isRunning ?? false)
    }

    private var effectiveUntil: Date { isRunning ? .now : until }

    private var isTooLong: Bool {
        effectiveUntil.timeIntervalSince(from) > TimeMath.maxEntryDuration
    }

    private var isValid: Bool {
        project != nil && (isRunning || until > from) && !isTooLong
    }

    private func overlapping(until end: Date) -> [Entry] {
        allEntries.filter { other in
            other != entry &&
            TimeMath.overlaps(from, end, other.from, other.end())
        }
        .sorted { $0.from < $1.from }
    }

    private func resolution(of other: Entry, until end: Date) -> TimeMath.OverlapResolution {
        TimeMath.overlapResolution(from: from, until: end, otherFrom: other.from, otherEnd: other.end())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Project", selection: $project) {
                        if project == nil { Text("Choose…").tag(Project?.none) }
                        ForEach(projects) { p in
                            Text(p.name).tag(Optional(p))
                        }
                    }
                    TaskField(text: $taskText, project: project)
                }

                Section {
                    DatePicker("From", selection: $from)
                    if entry?.isRunning == true {
                        Toggle("Running", isOn: $isRunning)
                    }
                    if !isRunning {
                        DatePicker("Until", selection: $until)
                    }
                } footer: {
                    if !isRunning && until <= from {
                        Text("“Until” must be after “From”.").foregroundStyle(.red)
                    } else if isTooLong {
                        Text("An entry can't be longer than 24 hours.").foregroundStyle(.red)
                    } else {
                        Text("Duration: \(TimeMath.format(effectiveUntil.timeIntervalSince(from)))")
                    }
                }

                let overlapping = overlapping(until: effectiveUntil)
                if !overlapping.isEmpty {
                    Section {
                        ForEach(overlapping) { other in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(other.project?.name ?? "—"): \(Self.range(other))")
                                Text(Self.describe(resolution(of: other, until: effectiveUntil)))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Label("Overlapping entries", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("Saving deletes the entries this one fully covers and truncates the ones it partly overlaps.")
                    }
                }

                if entry != nil {
                    Section {
                        Button("Delete Entry", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(entry == nil ? "New Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!isValid)
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let entry { context.delete(entry) }
                    TimerService.didChange(context)
                    dismiss()
                }
            }
            .onAppear {
                if entry == nil && project == nil { project = projects.first }
            }
        }
    }

    private func save() {
        let end = isRunning ? Date.now : until
        resolveOverlaps(until: end)
        let target: Entry
        if let entry {
            target = entry
        } else {
            target = Entry(from: from, until: until, project: project, task: nil)
            context.insert(target)
        }
        target.project = project
        target.task = taskText.normalizedTask
        target.from = from
        target.until = isRunning ? nil : until
        TimerService.didChange(context)
        dismiss()
    }

    /// The saved entry wins: covered entries are deleted, partly overlapping ones truncated.
    private func resolveOverlaps(until end: Date) {
        for other in overlapping(until: end) {
            switch resolution(of: other, until: end) {
            case .delete:
                context.delete(other)
            case .trimEnd(let date):
                other.until = date
            case .trimStart(let date):
                other.from = date
            case .split(let before, let after):
                // The part after keeps the original end (and keeps running if it was).
                context.insert(Entry(from: after, until: other.until, project: other.project, task: other.task))
                other.until = before
            }
        }
    }

    private static func describe(_ resolution: TimeMath.OverlapResolution) -> String {
        func time(_ d: Date) -> String { d.formatted(date: .omitted, time: .shortened) }
        switch resolution {
        case .delete: return "Will be deleted"
        case .trimEnd(let d): return "Will end at \(time(d))"
        case .trimStart(let d): return "Will start at \(time(d))"
        case .split(let a, let b): return "Will be split: until \(time(a)) and from \(time(b))"
        }
    }

    private static func range(_ e: Entry) -> String {
        let start = e.from.formatted(date: .abbreviated, time: .shortened)
        let end = e.until?.formatted(date: .omitted, time: .shortened) ?? "now"
        return "\(start) – \(end)"
    }
}

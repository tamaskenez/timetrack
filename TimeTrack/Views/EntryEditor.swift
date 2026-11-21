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

    private var isValid: Bool {
        project != nil && (isRunning || until > from)
    }

    private var overlapping: [Entry] {
        allEntries.filter { other in
            other != entry &&
            TimeMath.overlaps(from, effectiveUntil, other.from, other.end())
        }
        .sorted { $0.from < $1.from }
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
                    } else {
                        Text("Duration: \(TimeMath.format(effectiveUntil.timeIntervalSince(from)))")
                    }
                }

                if !overlapping.isEmpty {
                    Section {
                        ForEach(overlapping) { other in
                            Text("\(other.project?.name ?? "—"): \(Self.range(other))")
                        }
                    } header: {
                        Label("Overlaps with", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("You can still save.")
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

    private static func range(_ e: Entry) -> String {
        let start = e.from.formatted(date: .abbreviated, time: .shortened)
        let end = e.until?.formatted(date: .omitted, time: .shortened) ?? "now"
        return "\(start) – \(end)"
    }
}

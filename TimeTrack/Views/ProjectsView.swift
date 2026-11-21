import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    @State private var nameDraft = ""
    @State private var adding = false
    @State private var renaming: Project?
    @State private var deleting: Project?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(projects) { project in
                    Button {
                        nameDraft = project.name
                        renaming = project
                    } label: {
                        HStack {
                            Text(project.name).foregroundStyle(.primary)
                            Spacer()
                            // All-time total; refreshes each minute so a running timer is included.
                            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                                let total = (project.entries ?? []).reduce(0) { $0 + $1.duration(now: timeline.date) }
                                Text(TimeMath.format(total))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete { offsets in
                    deleting = offsets.first.map { projects[$0] }
                }
            }
            .overlay {
                if projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder",
                        description: Text("Tap + to add your first project."))
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        nameDraft = ""
                        adding = true
                    } label: { Image(systemName: "plus") }
                }
            }
            .alert("New Project", isPresented: $adding) {
                TextField("Name", text: $nameDraft)
                Button("Cancel", role: .cancel) {}
                Button("Add") { add() }
            }
            .alert("Rename Project", isPresented: isPresent($renaming), presenting: renaming) { project in
                TextField("Name", text: $nameDraft)
                Button("Cancel", role: .cancel) {}
                Button("Save") { rename(project) }
            }
            .confirmationDialog(
                deleteTitle,
                isPresented: isPresent($deleting),
                titleVisibility: .visible,
                presenting: deleting
            ) { project in
                Button("Delete", role: .destructive) { delete(project) }
            }
            .alert("Can't Save", isPresented: isPresent($errorMessage)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var deleteTitle: String {
        guard let deleting else { return "" }
        let count = deleting.entries?.count ?? 0
        return count == 0
            ? "Delete “\(deleting.name)”?"
            : "Delete “\(deleting.name)” and its \(count) \(count == 1 ? "entry" : "entries")?"
    }

    /// Returns the trimmed name if valid and not used by another project; otherwise sets an error.
    private func validated(_ name: String, excluding: Project? = nil) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            errorMessage = "The project name can't be empty."
            return nil
        }
        if projects.contains(where: { $0 != excluding && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            errorMessage = "A project named “\(trimmed)” already exists."
            return nil
        }
        return trimmed
    }

    private func add() {
        guard let name = validated(nameDraft) else { return }
        let order = (projects.map(\.sortOrder).max() ?? -1) + 1
        context.insert(Project(name: name, sortOrder: order))
        TimerService.didChange(context)
    }

    private func rename(_ project: Project) {
        guard let name = validated(nameDraft, excluding: project) else { return }
        project.name = name
        TimerService.didChange(context)
    }

    private func delete(_ project: Project) {
        context.delete(project) // cascades to its entries
        TimerService.didChange(context)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = projects
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, project) in ordered.enumerated() where project.sortOrder != index {
            project.sortOrder = index
        }
        TimerService.didChange(context)
    }

    /// Bool binding that is true while `value` is non-nil; setting false clears it.
    private func isPresent<T>(_ value: Binding<T?>) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue != nil },
            set: { if !$0 { value.wrappedValue = nil } })
    }
}

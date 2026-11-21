import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(filter: #Predicate<Entry> { $0.until == nil }) private var running: [Entry]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let entry = running.first {
                        RunningCard(entry: entry)
                            .id(entry.persistentModelID)
                    } else {
                        IdleCard()
                    }

                    if projects.isEmpty {
                        ContentUnavailableView(
                            "No Projects",
                            systemImage: "folder.badge.plus",
                            description: Text("Add projects in the Projects tab."))
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            ForEach(projects) { project in
                                ProjectButton(
                                    project: project,
                                    isRunning: running.first?.project == project
                                ) {
                                    if running.first?.project != project {
                                        TimerService.start(project, context: context)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Timer")
        }
    }
}

private struct IdleCard: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Not tracking").font(.title2.weight(.semibold))
            Text("Tap a project to start.").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct RunningCard: View {
    @Environment(\.modelContext) private var context
    let entry: Entry

    @State private var taskText: String
    @State private var showStopAt = false
    @State private var showEditor = false

    init(entry: Entry) {
        self.entry = entry
        _taskText = State(initialValue: entry.task ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.project?.name ?? "—")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Edit") { showEditor = true }
                    .font(.subheadline)
            }

            Text(timerInterval: entry.from...entry.autoStopDate, countsDown: false)
                .font(.system(size: 48, weight: .medium, design: .rounded))
                .monospacedDigit()

            Text("Started \(entry.from.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TaskField(text: $taskText, project: entry.project) {
                let newTask = taskText.normalizedTask
                if newTask != entry.task {
                    entry.task = newTask
                    TimerService.didChange(context)
                }
            }
            .textFieldStyle(.roundedBorder)

            HStack {
                Button(role: .destructive) {
                    TimerService.stop(context: context)
                } label: {
                    Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button {
                    showStopAt = true
                } label: {
                    Text("Stop at…").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
        .task(id: entry.persistentModelID) {
            // Auto-stop while the app stays open; otherwise it happens on next activation.
            let wait = entry.autoStopDate.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if !Task.isCancelled { TimerService.didChange(context) }
        }
        .onChange(of: entry.task) { _, newValue in
            taskText = newValue ?? ""  // edited elsewhere (e.g. in the entry editor)
        }
        .sheet(isPresented: $showStopAt) {
            StopAtSheet(start: entry.from) { date in
                TimerService.stop(at: date, context: context)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showEditor) {
            EntryEditor(entry: entry)
        }
    }
}

private struct StopAtSheet: View {
    @Environment(\.dismiss) private var dismiss
    let start: Date
    let onStop: (Date) -> Void

    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Stopped at", selection: $date,
                           in: start...min(Date.now, start.addingTimeInterval(TimeMath.maxEntryDuration)))
                Text("Duration: \(TimeMath.format(date.timeIntervalSince(start)))")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Stop at…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Stop") {
                        onStop(date)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ProjectButton: View {
    let project: Project
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isRunning ? "record.circle" : "play.fill")
                Text(project.name)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity, minHeight: 64)
            .foregroundStyle(isRunning ? Color.white : Color.primary)
            .background(
                isRunning ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.fill.secondary),
                in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

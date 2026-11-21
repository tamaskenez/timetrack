import SwiftUI
import SwiftData
import WidgetKit
import AppIntents

/// Inside TimelineProvider, `Entry` means the timeline entry type, so refer to the model by this alias.
private typealias TrackedEntry = Entry

struct TimerWidgetEntry: TimelineEntry {
    struct Running {
        var projectName: String
        var task: String?
        var startedAt: Date
    }

    var date: Date
    var running: Running?
    /// Tracked today up to `date`, including the running entry.
    var todayTotal: TimeInterval
    var projectNames: [String]

    static let placeholder = TimerWidgetEntry(
        date: .now,
        running: Running(projectName: "Project", task: nil, startedAt: .now.addingTimeInterval(-1800)),
        todayTotal: 3 * 3600,
        projectNames: ["Project A", "Project B", "Project C", "Project D"])
}

struct TimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerWidgetEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TimerWidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerWidgetEntry>) -> Void) {
        let entry = load()
        // The app reloads the widget on every change; this only rolls the "today" total over.
        let next = min(entry.date.addingTimeInterval(30 * 60), TimeMath.today(now: entry.date).end)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load(now: Date = .now) -> TimerWidgetEntry {
        let context = ModelContext(SharedStore.container)
        let today = TimeMath.today(now: now)
        let end = today.end

        let projects = (try? context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let running = (try? context.fetch(FetchDescriptor<TrackedEntry>(predicate: #Predicate { $0.until == nil })))?.first
        // Entries starting before tomorrow; TimeMath clips them to today.
        let todays = (try? context.fetch(FetchDescriptor<TrackedEntry>(
            predicate: #Predicate { $0.from < end }))) ?? []

        return TimerWidgetEntry(
            date: now,
            running: running.map {
                .init(projectName: $0.project?.name ?? "—", task: $0.task, startedAt: $0.from)
            },
            todayTotal: TimeMath.total(todays, in: today, now: now),
            projectNames: projects.map(\.name))
    }
}

struct TimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TimerWidget", provider: TimerProvider()) { entry in
            TimerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Timer")
        .description("The running timer and today's total.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TimerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimerWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 12) {
                status
                startButtons
            }
        default:
            status
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let running = entry.running {
                Text(running.projectName)
                    .font(.headline)
                    .lineLimit(1)
                if let task = running.task {
                    Text(task).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(running.startedAt, style: .timer)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Spacer(minLength: 0)
                todayLine
                Button(intent: StopTimerIntent()) {
                    Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                .tint(.red)
            } else {
                Text("Not tracking").font(.headline)
                Spacer(minLength: 0)
                todayLine
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var todayLine: some View {
        HStack(spacing: 4) {
            Text("Today")
            if entry.running != nil {
                // Counts up live from today's total.
                Text(entry.date.addingTimeInterval(-entry.todayTotal), style: .timer)
                    .monospacedDigit()
            } else {
                Text(TimeMath.format(entry.todayTotal))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var startButtons: some View {
        VStack(spacing: 6) {
            ForEach(entry.projectNames.prefix(4), id: \.self) { name in
                let isRunning = entry.running?.projectName == name
                Button(intent: StartTimerIntent(projectName: name)) {
                    Text(name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .tint(isRunning ? .accentColor : .secondary)
                .disabled(isRunning)
            }
            if entry.projectNames.isEmpty {
                Text("Add projects in the app").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

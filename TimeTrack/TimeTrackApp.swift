import SwiftUI
import SwiftData

@main
struct TimeTrackApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(SharedStore.container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Timer", systemImage: "timer") { TimerView() }
            Tab("Entries", systemImage: "list.bullet") { EntriesView() }
            Tab("Totals", systemImage: "chart.bar") { TotalsView() }
            Tab("Projects", systemImage: "folder") { ProjectsView() }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Re-sync the widget and Live Activity (e.g. after a reinstall or a crash).
            if phase == .active { TimerService.didChange(context) }
        }
    }
}

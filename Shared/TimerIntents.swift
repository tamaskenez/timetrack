import AppIntents
import SwiftData

// LiveActivityIntent makes the system run these in the app's process, even when
// tapped in the widget or the Live Activity. So all writes happen in the app,
// on the same main context the UI uses, and the Live Activity can be started
// from the background.

struct StartTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Timer"
    static let isDiscoverable = false

    @Parameter(title: "Project")
    var projectName: String

    init() {}
    init(projectName: String) { self.projectName = projectName }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = SharedStore.container.mainContext
        let name = projectName
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.name == name })
        if let project = try context.fetch(descriptor).first {
            TimerService.start(project, context: context)
        }
        return .result()
    }
}

struct StopTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Timer"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        TimerService.stop(context: SharedStore.container.mainContext)
        return .result()
    }
}

import Foundation
import SwiftData

/// The one SwiftData container, stored in the App Group so the app and the
/// widget extension share it.
enum SharedStore {
    /// Read from Info.plist (`AppGroupID`, filled from the `APP_GROUP_ID` build setting).
    static let appGroupID: String = {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String, !id.isEmpty else {
            fatalError("AppGroupID missing from Info.plist; set APP_GROUP_ID in project.yml")
        }
        return id
    }()

    static let container: ModelContainer = {
        let schema = Schema([Project.self, Entry.self])
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(appGroupID),
            cloudKitDatabase: .none // switch to .private("iCloud.<id>") to enable sync later
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}

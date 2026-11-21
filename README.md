# TimeTrack

A simple time tracking app for iOS 18+ (SwiftUI + SwiftData), with a Home Screen
widget and a Live Activity. See [SPEC.md](SPEC.md) for the feature spec.

## Setup

1. Install XcodeGen: `brew install xcodegen` or `sudo port install xcodegen`
2. In `project.yml`, set your values at the top:
   - `DEVELOPMENT_TEAM`: your Apple team ID
   - `BUNDLE_ID_BASE`: e.g. `com.yourname.timetrack` (the widget gets `.widget` appended)
   - `APP_GROUP_ID`: e.g. `group.com.yourname.timetrack`
3. Generate and open the project:
   ```sh
   xcodegen generate
   open TimeTrack.xcodeproj
   ```
4. Build and run the `TimeTrack` scheme on a device or simulator.

Re-run `xcodegen generate` after adding or removing files. The `.xcodeproj`,
`Info.plist` and `.entitlements` files are generated and not committed.

## Layout

```
project.yml          XcodeGen spec (app + widget extension)
Shared/              Compiled into both targets
  Models.swift         SwiftData models: Project, Entry
  SharedStore.swift    ModelContainer in the App Group
  TimerService.swift   Start/stop logic, task suggestions, widget + Live Activity refresh
  TimerIntents.swift   Start/Stop App Intents (used by widget and Live Activity buttons)
  LiveActivity.swift   ActivityAttributes + controller
  TimeMath.swift       Calendar (Monday weeks), clipping, overlap, formatting
TimeTrack/           App target
  TimeTrackApp.swift   App entry + tab view
  Views/               Timer, Entries, EntryEditor, Totals, Projects, TaskField
TimeTrackWidget/     Widget extension: Home Screen widget + Live Activity UI
```

## How the pieces talk

- All data lives in one SwiftData store in the App Group container.
- Every change goes through `TimerService.didChange`, which saves, reloads
  widget timelines and syncs the Live Activity.
- Widget and Live Activity buttons use `LiveActivityIntent`s, which the system
  runs in the app's process. So writes always happen in the app, on the same
  main context the UI uses, and the Live Activity can start from the background.
- The widget extension only reads the store.

## Enabling iCloud sync later

The models already follow CloudKit's rules. Add the iCloud (CloudKit) and
Background Modes (remote notifications) capabilities, then change
`cloudKitDatabase: .none` in `SharedStore.swift` to `.private("iCloud.<your id>")`.

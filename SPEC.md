# TimeTrack — Specification

A simple personal time tracking app for iOS.

## Platform

- iOS 18+, iPhone, portrait.
- SwiftUI + SwiftData, WidgetKit, ActivityKit, App Intents.
- Project generated with XcodeGen (`project.yml`).

## Data model

Stored locally with SwiftData in a shared App Group container, so the app,
the widget and the Live Activity see the same data.

### Project
| Field       | Type     | Notes                                  |
|-------------|----------|----------------------------------------|
| `name`      | String   | Unique (case-insensitive), non-empty   |
| `sortOrder` | Int      | User-defined order (drag to reorder)   |
| `entries`   | [Entry]  | Cascade delete                         |

### Entry
| Field     | Type      | Notes                                   |
|-----------|-----------|-----------------------------------------|
| `from`    | Date      | Start                                   |
| `until`   | Date?     | End; `nil` while the timer is running   |
| `project` | Project?  | Optional only for CloudKit compatibility |
| `task`    | String?   | Optional free text; empty is stored as `nil` |

At most one entry is running (`until == nil`) at any time.

### iCloud sync — later
Local only for now. The model already follows CloudKit's rules (all properties
have defaults or are optional, relationships are optional, no unique
constraints), so sync can be enabled later by adding the CloudKit capability
and setting `cloudKitDatabase` in `SharedStore`.

## Features

### Recording
- **Live timer**: tap a project to start tracking it. Starting a timer while
  another is running stops the running one at the same instant (no overlaps,
  never more than one running).
- **Stop**: "Stop" ends the entry now; "Stop at…" lets you pick an earlier end
  time (between the start and now) for when you forgot to stop.
- **Task**: the running timer card has a task field with suggestions.
- **Manual entry**: add an entry with project, task, from, until.
- **Edit**: change project, task, from, until of any entry; delete an entry.
  A running entry can be stopped from the editor by turning off "Running".
- **Validation**: `until` must be after `from`. Overlapping another entry shows
  a warning but saving is allowed.
- **Task suggestions**: the task field suggests tasks previously used on the
  selected project, most recent first, filtered by what's typed.

### Outside the app
- **Live Activity** (Lock Screen + Dynamic Island) while a timer runs: project,
  task, elapsed time, and a Stop button.
- **Home Screen widget** (small, medium): running timer or "Not tracking",
  today's total, Stop button; medium size also shows project buttons to start
  a timer.

### Tabs
1. **Timer** — running timer card (project, task, elapsed, Stop, Stop at…) and
   a grid of project buttons.
2. **Entries** — entries grouped by day (by start date), newest first, daily
   totals. Tap to edit, swipe to delete, + to add manually.
3. **Totals** — Today / This week / This month. Total per project, expandable
   to a per-task breakdown. Entries are clipped to the period. Weeks start on
   Monday.
4. **Projects** — add, rename, delete (confirms and deletes the project's
   entries too), drag to reorder.

### Formatting
- Durations: `1h 23m`, `45m`, `0m`. No rounding of stored times.
- Running timers show seconds (`1:23:45`).

## Out of scope for now
- iCloud sync, CSV export, charts, Siri/Shortcuts, Control Center control,
  reminder notifications, custom date ranges.

import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .padding()
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.state.projectName).font(.headline).lineLimit(1)
                        if let task = context.state.task {
                            Text(task).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.timerRange, countsDown: false)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Button(intent: StopTimerIntent()) {
                        Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                    }
                    .tint(.red)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(timerInterval: context.state.timerRange, countsDown: false)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}

private struct LockScreenView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.projectName).font(.headline).lineLimit(1)
                if let task = state.task {
                    Text(task).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(timerInterval: state.timerRange, countsDown: false)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
            }
            Spacer()
            Button(intent: StopTimerIntent()) {
                Image(systemName: "stop.fill").font(.title2)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(.red)
        }
    }
}

extension TimerActivityAttributes.ContentState {
    /// Stops counting at the auto-stop time.
    var timerRange: ClosedRange<Date> {
        startedAt...startedAt.addingTimeInterval(TimeMath.maxEntryDuration)
    }
}

import SwiftUI
import WidgetKit

@main
struct TimeTrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerWidget()
        TimerLiveActivity()
    }
}

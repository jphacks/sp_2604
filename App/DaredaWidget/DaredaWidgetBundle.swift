import SwiftUI
import WidgetKit

@main
struct DaredaWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecordingLiveActivity()
        StartRecordingControl()
    }
}

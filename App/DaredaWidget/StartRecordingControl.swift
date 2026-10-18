import AppIntents
import SwiftUI
import WidgetKit

/// コントロールセンター・ロック画面・アクションボタンから録音を始める。
struct StartRecordingControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.kantacky.Dareda.StartRecordingControl") {
            ControlWidgetButton(action: StartRecordingIntent()) {
                Label("録音を開始", systemImage: "mic.fill")
            }
        }
        .displayName("録音を開始")
        .description("Dareda を開かずに会話の録音を始めます。")
    }
}

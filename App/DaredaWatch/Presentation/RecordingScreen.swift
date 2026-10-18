import SwiftUI

/// Apple Watch のマイクで録音中の画面。
struct RecordingScreen: View {
    @Environment(WatchRecorder.self) private var recorder
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        RecordingContent(
            elapsedTime: recorder.elapsedTime,
            stopTapped: {
                recorder.stop()
                dismiss()
            },
            discardTapped: {
                recorder.discard()
                dismiss()
            }
        )
        .onChange(of: recorder.isRecording) { _, isRecording in
            // 上限や中断で止まったときも閉じる
            if !isRecording { dismiss() }
        }
    }
}

struct RecordingContent: View {
    let elapsedTime: TimeInterval
    let stopTapped: () -> Void
    let discardTapped: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.title)
                .foregroundStyle(.red)
                .symbolEffect(.variableColor.iterative)
            Text(Duration.seconds(elapsedTime).formatted(.time(pattern: .minuteSecond)))
                .font(.title2.monospacedDigit())
                .accessibilityIdentifier("watch.elapsedTime")
            Button(action: stopTapped) {
                Label("停止して送信", systemImage: "stop.fill")
            }
            .tint(.red)
            .accessibilityIdentifier("watch.stopButton")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("破棄", systemImage: "trash", role: .destructive, action: discardTapped)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecordingContent(elapsedTime: 42, stopTapped: {}, discardTapped: {})
    }
}

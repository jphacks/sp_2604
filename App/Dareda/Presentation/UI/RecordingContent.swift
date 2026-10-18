import SwiftUI

struct RecordingContent: View {
    let isRecording: Bool
    let isStarting: Bool
    let recording: Recording?
    let elapsedTime: TimeInterval
    let wasInterrupted: Bool
    let reachedLimit: Bool
    var isOneMinuteRemaining = false
    let isProcessing: Bool
    let errorMessage: LocalizedStringResource?
    let isDiscardConfirmationPresented: Bool
    var isImported = false
    let send: (RecordingViewModel.Action) -> Void

    private var hasRecording: Bool { recording != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    RecordingStatusContent(
                        isRecording: isRecording, isStarting: isStarting, hasRecording: hasRecording,
                        isImported: isImported,
                        elapsedTime: elapsedTime, wasInterrupted: wasInterrupted,
                        reachedLimit: reachedLimit, isOneMinuteRemaining: isOneMinuteRemaining
                    )
                    if isRecording {
                        Button("録音を停止", systemImage: "stop.fill") { send(.stopButtonTapped) }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .accessibilityIdentifier("recording.stopButton")
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("recording.errorNotice")
                        if !hasRecording, !isImported {
                            Button("もう一度録音する") { send(.retryButtonTapped) }
                                .accessibilityIdentifier("recording.retryButton")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            .navigationTitle("会話の録音")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { send(.discardButtonTapped) }
                        .disabled(isStarting)
                        .accessibilityIdentifier("recording.discardButton")
                        // iPad ではポップオーバーの起点になるため、トリガーのボタンに付ける
                        .confirmationDialog(
                            isProcessing ? "処理をキャンセルしますか？" : "録音を破棄しますか？",
                            isPresented: Binding(
                                get: { isDiscardConfirmationPresented },
                                set: { send(.discardConfirmationChanged($0)) }
                            ),
                            titleVisibility: .visible
                        ) {
                            Button(isProcessing ? "キャンセルする" : "録音を破棄", role: .destructive) {
                                send(.discardConfirmed)
                            }
                            .accessibilityIdentifier("recording.confirmDiscardButton")
                            Button(isProcessing ? "続ける" : "破棄しない", role: .cancel) {
                                send(.discardConfirmationChanged(false))
                            }
                            .accessibilityIdentifier("recording.cancelDiscardButton")
                        } message: {
                            Text(
                                isProcessing
                                    ? "録音と処理中のデータは削除され、元に戻せません。"
                                    : "この録音は削除されます。"
                            )
                        }
                }
            }
            .navigationDestination(isPresented: .constant(isProcessing)) {
                if let recording, isProcessing {
                    ProcessingScreen(
                        recording: recording,
                        onFinished: { send(.processingFinished($0)) },
                        onRerecord: { send(.rerecordRequested) }
                    )
                }
            }
        }
        .interactiveDismissDisabled()
    }
}

private struct RecordingStatusContent: View {
    private static let maxMinutes = Int(ProvisionalParameters.recordingMaxDuration / 60)

    let isRecording: Bool
    let isStarting: Bool
    let hasRecording: Bool
    var isImported = false
    let elapsedTime: TimeInterval
    let wasInterrupted: Bool
    let reachedLimit: Bool
    var isOneMinuteRemaining = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isRecording ? "waveform" : isImported ? "doc.fill" : "mic.fill")
                .font(.largeTitle)
                .foregroundStyle(isRecording ? .red : .primary)
                .accessibilityHidden(true)
            if isStarting {
                ProgressView("録音を開始しています")
            } else if isRecording {
                Text("録音中")
                    .font(.title2.bold())
                    .accessibilityIdentifier("recording.recordingNotice")
            } else if hasRecording {
                Text(isImported ? "音声ファイル" : "録音終了")
                    .font(.title2.bold())
            } else if isImported {
                Text("音声ファイルを読み込めませんでした")
                    .font(.title2.bold())
            } else {
                Text("録音を開始できませんでした")
                    .font(.title2.bold())
            }
            Text(Duration.seconds(elapsedTime), format: .time(pattern: .minuteSecond))
                .font(.largeTitle.monospacedDigit())
                .accessibilityIdentifier("recording.elapsedTime")
            if isRecording, isOneMinuteRemaining {
                Text("残り1分です。\(Self.maxMinutes)分で自動的に録音を停止します。")
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("recording.remainingMinuteNotice")
            }
            if wasInterrupted {
                Text("録音が中断されました。中断までの録音を保持しています。")
                    .accessibilityIdentifier("recording.interruptionNotice")
            }
            if reachedLimit {
                Text("上限の\(Self.maxMinutes)分に達したため、録音を停止しました。")
                    .accessibilityIdentifier("recording.limitNotice")
            }
        }
    }
}

/// 解析の処理状況。詳細な表示と再試行 UI は #29 で作る。
#Preview("録音中") {
    RecordingContent(isRecording: true, isStarting: false, recording: Recording(id: UUID(), fileURL: URL(filePath: "/tmp/a.m4a"), startedAt: .now, duration: 120),
        elapsedTime: 540, wasInterrupted: false, reachedLimit: false,
        isProcessing: false, errorMessage: nil, isDiscardConfirmationPresented: false, send: { _ in })
}

#Preview("録音後") {
    RecordingContent(isRecording: false, isStarting: false, recording: Recording(id: UUID(), fileURL: URL(filePath: "/tmp/a.m4a"), startedAt: .now, duration: 120),
        elapsedTime: 120, wasInterrupted: true, reachedLimit: false,
        isProcessing: false, errorMessage: nil, isDiscardConfirmationPresented: false, send: { _ in })
}

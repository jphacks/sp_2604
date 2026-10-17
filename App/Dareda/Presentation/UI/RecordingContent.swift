import SwiftUI

struct RecordingContent: View {
    let isRecording: Bool
    let isStarting: Bool
    let recording: Recording?
    let elapsedTime: TimeInterval
    let wasInterrupted: Bool
    let reachedLimit: Bool
    var isOneMinuteRemaining = false
    let selectedMode: RecordingViewModel.Mode?
    let errorMessage: LocalizedStringResource?
    let isDiscardConfirmationPresented: Bool
    var isAdditional = false
    let send: (RecordingViewModel.Action) -> Void

    private var hasRecording: Bool { recording != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    RecordingStatusContent(
                        isRecording: isRecording, isStarting: isStarting, hasRecording: hasRecording,
                        elapsedTime: elapsedTime, wasInterrupted: wasInterrupted,
                        reachedLimit: reachedLimit, isOneMinuteRemaining: isOneMinuteRemaining
                    )
                    if isRecording {
                        Button("録音を停止", systemImage: "stop.fill") { send(.stopButtonTapped) }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .accessibilityIdentifier("recording.stopButton")
                    } else if hasRecording, isAdditional {
                        Button("この録音を追加", systemImage: "plus") { send(.addButtonTapped) }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("recording.addButton")
                    } else if hasRecording {
                        RecordingChoiceContent(send: send)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("recording.errorNotice")
                        if !hasRecording {
                            Button("もう一度録音する") { send(.retryButtonTapped) }
                                .accessibilityIdentifier("recording.retryButton")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            .navigationTitle(isAdditional ? "追加録音" : "会話の録音")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // 録音後の操作を選んだ後は、処理のキャンセルになる
                    Button(selectedMode == nil ? "破棄して閉じる" : "キャンセル") { send(.discardButtonTapped) }
                        .disabled(isStarting)
                        .accessibilityIdentifier("recording.discardButton")
                }
            }
            .sheet(isPresented: Binding(
                get: { isDiscardConfirmationPresented },
                set: { send(.discardConfirmationChanged($0)) }
            )) {
                if selectedMode == nil {
                    CancelConfirmation(
                        title: "録音を破棄しますか？",
                        message: "この録音は削除されます。",
                        confirmTitle: "録音を破棄",
                        keepTitle: "破棄しない",
                        identifierPrefix: "recording",
                        onConfirm: { send(.discardConfirmed) },
                        onKeep: { send(.discardConfirmationChanged(false)) }
                    )
                    .presentationDetents([.medium])
                } else {
                    CancelConfirmation(
                        title: "処理をキャンセルしますか？",
                        message: "録音と処理中のデータは削除され、元に戻せません。",
                        confirmTitle: "キャンセルする",
                        keepTitle: "続ける",
                        identifierPrefix: "recording",
                        onConfirm: { send(.discardConfirmed) },
                        onKeep: { send(.discardConfirmationChanged(false)) }
                    )
                    .presentationDetents([.medium])
                }
            }
            .navigationDestination(isPresented: .constant(selectedMode != nil)) {
                if let recording, let selectedMode {
                    ProcessingScreen(
                        recording: recording, mode: selectedMode,
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
    let elapsedTime: TimeInterval
    let wasInterrupted: Bool
    let reachedLimit: Bool
    var isOneMinuteRemaining = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isRecording ? "waveform" : "mic.fill")
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
                Text("録音終了")
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

private struct RecordingChoiceContent: View {
    let send: (RecordingViewModel.Action) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("この録音で何をしますか？").font(.headline)
            Button("新規登録", systemImage: "person.badge.plus") { send(.registrationButtonTapped) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("recording.registrationButton")
            Button("人物を探す", systemImage: "person.crop.circle.badge.magnifyingglass") { send(.searchButtonTapped) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("recording.searchButton")
        }
    }
}

/// 解析の処理状況。詳細な表示と再試行 UI は #29 で作る。
#Preview("録音中") {
    RecordingContent(isRecording: true, isStarting: false, recording: Recording(id: UUID(), fileURL: URL(filePath: "/tmp/a.m4a"), startedAt: .now, duration: 120),
        elapsedTime: 540, wasInterrupted: false, reachedLimit: false,
        selectedMode: nil, errorMessage: nil, isDiscardConfirmationPresented: false, send: { _ in })
}

#Preview("録音後") {
    RecordingContent(isRecording: false, isStarting: false, recording: Recording(id: UUID(), fileURL: URL(filePath: "/tmp/a.m4a"), startedAt: .now, duration: 120),
        elapsedTime: 120, wasInterrupted: true, reachedLimit: false,
        selectedMode: nil, errorMessage: nil, isDiscardConfirmationPresented: false, send: { _ in })
}

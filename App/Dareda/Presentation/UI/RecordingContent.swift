import SwiftUI

struct RecordingContent: View {
    let isRecording: Bool
    let isStarting: Bool
    let hasRecording: Bool
    let elapsedTime: TimeInterval
    let wasInterrupted: Bool
    let reachedLimit: Bool
    var isOneMinuteRemaining = false
    let selectedMode: RecordingViewModel.Mode?
    let errorMessage: LocalizedStringResource?
    let isDiscardConfirmationPresented: Bool
    let send: (RecordingViewModel.Action) -> Void

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
                    } else if hasRecording {
                        RecordingChoiceContent(selectedMode: selectedMode, send: send)
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
            .navigationTitle("会話の録音")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("破棄して閉じる") { send(.discardButtonTapped) }
                        .disabled(isStarting)
                        .accessibilityIdentifier("recording.discardButton")
                }
            }
            .sheet(isPresented: Binding(
                get: { isDiscardConfirmationPresented },
                set: { send(.discardConfirmationChanged($0)) }
            )) {
                RecordingDiscardConfirmationContent(send: send)
                    .presentationDetents([.medium])
            }
        }
        .interactiveDismissDisabled()
    }
}

private struct RecordingDiscardConfirmationContent: View {
    let send: (RecordingViewModel.Action) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("録音を破棄しますか？").font(.title2.bold())
            Text("この録音は削除されます。")
            Button("録音を破棄", role: .destructive) { send(.discardConfirmed) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("recording.confirmDiscardButton")
            Button("録音を続ける", role: .cancel) { send(.discardConfirmationChanged(false)) }
                .accessibilityIdentifier("recording.cancelDiscardButton")
        }
        .padding()
    }
}

private struct RecordingStatusContent: View {
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
                Text("残り1分です。10分で自動的に録音を停止します。")
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("recording.remainingMinuteNotice")
            }
            if wasInterrupted {
                Text("録音が中断されました。中断までの録音を保持しています。")
                    .accessibilityIdentifier("recording.interruptionNotice")
            }
            if reachedLimit {
                Text("上限の10分に達したため、録音を停止しました。")
                    .accessibilityIdentifier("recording.limitNotice")
            }
        }
    }
}

private struct RecordingChoiceContent: View {
    let selectedMode: RecordingViewModel.Mode?
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
            if let selectedMode {
                Text(selectedMode == .registration ? "新規登録を選択しました" : "人物を探すを選択しました")
                    .accessibilityIdentifier(selectedMode == .registration
                        ? "recording.selectedMode.registration" : "recording.selectedMode.search")
            }
        }
    }
}

#Preview("録音中") {
    RecordingContent(isRecording: true, isStarting: false, hasRecording: true,
        elapsedTime: 540, wasInterrupted: false, reachedLimit: false,
        selectedMode: nil, errorMessage: nil, isDiscardConfirmationPresented: false, send: { _ in })
}

#Preview("録音後") {
    RecordingContent(isRecording: false, isStarting: false, hasRecording: true,
        elapsedTime: 120, wasInterrupted: true, reachedLimit: false,
        selectedMode: nil, errorMessage: nil, isDiscardConfirmationPresented: false, send: { _ in })
}

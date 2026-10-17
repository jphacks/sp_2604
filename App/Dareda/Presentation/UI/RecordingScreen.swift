import SwiftUI

struct RecordingScreen: View {
    @State private var viewModel = RecordingViewModel()
    /// 新規登録で保存した場合はそのプロフィールの ID を渡す。
    let onFinished: (Profile.ID?) -> Void

    var body: some View {
        RecordingContent(
            isRecording: viewModel.isRecording,
            isStarting: viewModel.isStarting,
            recording: viewModel.recording,
            elapsedTime: viewModel.elapsedTime,
            wasInterrupted: viewModel.wasInterrupted,
            reachedLimit: viewModel.reachedLimit,
            isOneMinuteRemaining: viewModel.isOneMinuteRemaining,
            selectedMode: viewModel.selectedMode,
            errorMessage: viewModel.errorMessage,
            isDiscardConfirmationPresented: viewModel.isDiscardConfirmationPresented,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { onFinished(viewModel.registeredProfileID) }
        }
    }
}

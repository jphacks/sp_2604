import SwiftUI

struct RecordingScreen: View {
    @State private var viewModel = RecordingViewModel()
    let onFinished: () -> Void

    var body: some View {
        RecordingContent(
            isRecording: viewModel.isRecording,
            isStarting: viewModel.isStarting,
            hasRecording: viewModel.recording != nil,
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
            if finished { onFinished() }
        }
    }
}

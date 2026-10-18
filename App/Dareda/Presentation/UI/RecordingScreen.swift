import SwiftUI

struct RecordingScreen: View {
    @State private var viewModel: RecordingViewModel
    /// 新規登録で保存した場合や、人物検索で人物を確定した場合はそのプロフィールの ID を渡す。
    let onFinished: (Profile.ID?) -> Void

    init(
        importedFileURL: URL? = nil,
        onFinished: @escaping (Profile.ID?) -> Void
    ) {
        _viewModel = State(initialValue: RecordingViewModel(importedFileURL: importedFileURL))
        self.onFinished = onFinished
    }

    var body: some View {
        RecordingContent(
            isRecording: viewModel.isRecording,
            isStarting: viewModel.isStarting,
            recording: viewModel.recording,
            elapsedTime: viewModel.elapsedTime,
            wasInterrupted: viewModel.wasInterrupted,
            reachedLimit: viewModel.reachedLimit,
            isOneMinuteRemaining: viewModel.isOneMinuteRemaining,
            isProcessing: viewModel.isProcessing,
            errorMessage: viewModel.errorMessage,
            isDiscardConfirmationPresented: viewModel.isDiscardConfirmationPresented,
            isImported: viewModel.isImported,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { onFinished(viewModel.registeredProfileID) }
        }
    }
}

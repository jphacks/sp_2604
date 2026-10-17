import SwiftUI

struct RecordingScreen: View {
    @State private var viewModel: RecordingViewModel
    /// 新規登録で保存した場合や、人物検索で人物を確定した場合はそのプロフィールの ID を渡す。
    let onFinished: (Profile.ID?) -> Void
    /// 追加録音で「追加する」を選んだときに録音を渡す。
    let onAdded: (Recording) -> Void

    init(
        isAdditional: Bool = false,
        importedFileURL: URL? = nil,
        onFinished: @escaping (Profile.ID?) -> Void,
        onAdded: @escaping (Recording) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: RecordingViewModel(isAdditional: isAdditional, importedFileURL: importedFileURL))
        self.onFinished = onFinished
        self.onAdded = onAdded
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
            selectedMode: viewModel.selectedMode,
            errorMessage: viewModel.errorMessage,
            isDiscardConfirmationPresented: viewModel.isDiscardConfirmationPresented,
            isAdditional: viewModel.isAdditional,
            isImported: viewModel.isImported,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
        .onChange(of: viewModel.isFinished) { _, finished in
            guard finished else { return }
            if let added = viewModel.addedRecording {
                onAdded(added)
            } else {
                onFinished(viewModel.registeredProfileID)
            }
        }
    }
}

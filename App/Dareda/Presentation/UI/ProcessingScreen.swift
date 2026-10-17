import SwiftUI

struct ProcessingScreen: View {
    @State private var viewModel: ProcessingViewModel
    @Environment(\.scenePhase) private var scenePhase
    /// 新規登録で保存した場合はそのプロフィールの ID を渡す。
    let onFinished: (Profile.ID?) -> Void

    init(recording: Recording, mode: RecordingViewModel.Mode, onFinished: @escaping (Profile.ID?) -> Void) {
        _viewModel = State(initialValue: ProcessingViewModel(recording: recording, mode: mode))
        self.onFinished = onFinished
    }

    var body: some View {
        ProcessingContent(
            mode: viewModel.mode,
            stages: viewModel.stages.map { ($0, viewModel.status(of: $0)) },
            errorMessage: viewModel.errorMessage,
            canRetry: viewModel.failedStage != nil,
            isCompleted: viewModel.isCompleted,
            isSuspended: viewModel.isSuspended,
            needsSelfSelection: viewModel.needsSelfSelection,
            isCancelConfirmationPresented: viewModel.isCancelConfirmationPresented,
            registrationSource: viewModel.registrationSource,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.send(.sceneBecameActive) }
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { onFinished(viewModel.registeredProfileID) }
        }
    }
}

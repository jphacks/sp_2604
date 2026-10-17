import SwiftUI

struct ProcessingScreen: View {
    @State private var viewModel: ProcessingViewModel
    let onFinished: () -> Void

    init(recording: Recording, mode: RecordingViewModel.Mode, onFinished: @escaping () -> Void) {
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
            needsSelfSelection: viewModel.needsSelfSelection,
            isCancelConfirmationPresented: viewModel.isCancelConfirmationPresented,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { onFinished() }
        }
    }
}

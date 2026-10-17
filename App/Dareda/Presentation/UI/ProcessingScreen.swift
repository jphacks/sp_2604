import SwiftUI

struct ProcessingScreen: View {
    @State private var viewModel: ProcessingViewModel
    @Environment(\.scenePhase) private var scenePhase
    /// 新規登録で保存した場合はそのプロフィールの ID を渡す。
    let onFinished: (Profile.ID?) -> Void
    let onRerecord: () -> Void

    init(
        recording: Recording,
        onFinished: @escaping (Profile.ID?) -> Void, onRerecord: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: ProcessingViewModel(recording: recording))
        self.onFinished = onFinished
        self.onRerecord = onRerecord
    }

    var body: some View {
        ProcessingContent(
            stages: viewModel.stages.map { ($0, viewModel.status(of: $0)) },
            errorMessage: viewModel.errorMessage,
            canRetry: viewModel.failedStage != nil,
            isCompleted: viewModel.isCompleted,
            isSuspended: viewModel.isSuspended,
            selfSelectionAnalysis: viewModel.selfSelectionAnalysis,
            isCancelConfirmationPresented: viewModel.isCancelConfirmationPresented,
            registrationSource: viewModel.registrationSource,
            searchCandidates: viewModel.searchCandidates,
            insufficientPartnerSpeechDuration: viewModel.insufficientPartnerSpeechDuration,
            isConfirming: viewModel.isConfirming,
            isManualSelectionPresented: viewModel.isManualSelectionPresented,
            manualSelectionProfiles: viewModel.manualSelectionProfiles,
            isAdditionalRecordingPresented: viewModel.isAdditionalRecordingPresented,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.send(.sceneBecameActive) }
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { onFinished(viewModel.registeredProfileID) }
        }
        .onChange(of: viewModel.isRerecordRequested) { _, requested in
            if requested { onRerecord() }
        }
    }
}

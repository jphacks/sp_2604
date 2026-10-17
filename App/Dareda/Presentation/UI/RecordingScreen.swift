import SwiftUI

struct RecordingScreen: View {
    @State private var viewModel = RecordingViewModel()
    @Environment(\.scenePhase) private var scenePhase
    /// 新規登録で保存した場合はそのプロフィールの ID を渡す。
    let onFinished: (Profile.ID?) -> Void

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
            analysisStage: viewModel.analysisStage,
            isAnalysisCompleted: viewModel.isAnalysisCompleted,
            isAnalysisSuspended: viewModel.isAnalysisSuspended,
            analysisErrorMessage: viewModel.analysisErrorMessage,
            registrationSource: viewModel.registrationSource,
            registrationNotice: viewModel.registrationNotice,
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

import SwiftUI

struct RootScreen: View {
    @State private var viewModel = RootViewModel()

    var body: some View {
        RootContent(
            recordingPermission: viewModel.recordingPermission,
            isRequestingPermission: viewModel.isRequestingPermission,
            settingsErrorMessage: viewModel.settingsErrorMessage,
            availability: viewModel.availability,
            isProfileListPresented: viewModel.isProfileListPresented,
            isRecordingPresented: viewModel.isRecordingPresented,
            isVoiceEnrollmentPresented: viewModel.isVoiceEnrollmentPresented,
            isPreparedForRecording: viewModel.isPreparedForRecording,
            preparationErrorMessage: viewModel.preparationErrorMessage,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
    }
}

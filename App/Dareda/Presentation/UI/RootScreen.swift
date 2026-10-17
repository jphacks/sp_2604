import SwiftUI

struct RootScreen: View {
    @State private var viewModel = RootViewModel()

    var body: some View {
        RootContent(
            isRequestingPermission: viewModel.isRequestingPermission,
            alert: viewModel.alert,
            availability: viewModel.availability,
            isSettingsPresented: viewModel.isSettingsPresented,
            isRecordingPresented: viewModel.isRecordingPresented,
            isVoiceEnrollmentPresented: viewModel.isVoiceEnrollmentPresented,
            isPreparedForRecording: viewModel.isPreparedForRecording,
            registeredProfileID: viewModel.registeredProfileID,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
    }
}

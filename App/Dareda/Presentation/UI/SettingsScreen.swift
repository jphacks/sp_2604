import SwiftUI

struct SettingsScreen: View {
    @State private var viewModel = SettingsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        SettingsContent(
            selfVoiceRegisteredAt: viewModel.selfVoiceRegisteredAt,
            isVoiceReregistrationPresented: viewModel.isVoiceReregistrationPresented,
            privateCloudComputeConsent: viewModel.privateCloudComputeConsent,
            recordingPermission: viewModel.recordingPermission,
            notificationPermission: viewModel.notificationPermission,
            appVersion: viewModel.appVersion,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.send(.sceneBecameActive) }
        }
    }
}

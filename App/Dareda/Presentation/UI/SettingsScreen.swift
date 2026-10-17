import SwiftUI

struct SettingsScreen: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        SettingsContent(
            selfVoiceRegisteredAt: viewModel.selfVoiceRegisteredAt,
            isVoiceReregistrationPresented: viewModel.isVoiceReregistrationPresented,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
    }
}

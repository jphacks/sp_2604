import SwiftUI

struct PrivateCloudComputeSettingsScreen: View {
    @State private var viewModel = PrivateCloudComputeSettingsViewModel()

    var body: some View {
        PrivateCloudComputeSettingsContent(
            consent: viewModel.consent,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
    }
}

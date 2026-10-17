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
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
    }
}

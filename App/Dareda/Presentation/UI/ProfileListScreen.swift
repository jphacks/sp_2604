import SwiftUI

struct ProfileListScreen<Header: View, Actions: View>: View {
    @State private var viewModel = ProfileListViewModel()
    @ViewBuilder let header: () -> Header
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        ProfileListContent(
            profiles: viewModel.profiles,
            path: viewModel.path,
            send: viewModel.send,
            header: header,
            actions: actions
        )
        .onAppear { viewModel.send(.onAppear) }
    }
}

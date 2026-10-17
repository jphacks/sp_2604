import SwiftUI

struct ProfileListScreen: View {
    @State private var viewModel = ProfileListViewModel()

    var body: some View {
        ProfileListContent(
            profiles: viewModel.profiles,
            path: viewModel.path,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
    }
}

import SwiftUI

struct ProfileDetailScreen: View {
    @State private var viewModel: ProfileDetailViewModel

    init(profileID: Profile.ID) {
        _viewModel = State(initialValue: ProfileDetailViewModel(profileID: profileID))
    }

    var body: some View {
        ProfileDetailContent(
            detail: viewModel.detail,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
    }
}

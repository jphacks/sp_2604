import SwiftUI

struct RootScreen: View {
    @State private var viewModel = RootViewModel()

    var body: some View {
        RootContent(
            availability: viewModel.availability,
            isProfileListPresented: viewModel.isProfileListPresented,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
    }
}

import SwiftUI

struct RootScreen: View {
    @State private var viewModel = RootViewModel()

    var body: some View {
        RootContent()
            .onAppear { viewModel.send(.onAppear) }
    }
}

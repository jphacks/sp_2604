import SwiftUI

struct ProfileListScreen<Header: View, Actions: View>: View {
    @State private var viewModel = ProfileListViewModel()
    /// 新規登録で保存したプロフィール。変わったら一覧を読み直して詳細を表示する。
    var registeredProfileID: Profile.ID?
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
        .onChange(of: registeredProfileID) { _, id in
            if let id { viewModel.send(.profileRegistered(id)) }
        }
    }
}

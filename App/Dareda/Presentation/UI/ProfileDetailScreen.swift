import SwiftUI

struct ProfileDetailScreen: View {
    @State private var viewModel: ProfileDetailViewModel
    /// 編集して保存したとき。一覧を読み直すために呼ぶ。
    let onUpdated: () -> Void
    /// 削除したとき。一覧を読み直して詳細を閉じるために呼ぶ。
    let onDeleted: () -> Void

    init(profileID: Profile.ID, onUpdated: @escaping () -> Void, onDeleted: @escaping () -> Void) {
        _viewModel = State(initialValue: ProfileDetailViewModel(profileID: profileID))
        self.onUpdated = onUpdated
        self.onDeleted = onDeleted
    }

    var body: some View {
        ProfileDetailContent(
            detail: viewModel.detail,
            isEditPresented: viewModel.isEditPresented,
            name: viewModel.name,
            affiliation: viewModel.affiliation,
            metAt: viewModel.metAt,
            place: viewModel.place,
            summary: viewModel.summary,
            isPlaceSearchPresented: viewModel.isPlaceSearchPresented,
            canSave: viewModel.canSave,
            isDeleteConfirmationPresented: viewModel.isDeleteConfirmationPresented,
            isProcessing: viewModel.isProcessing,
            errorMessage: viewModel.errorMessage,
            send: viewModel.send
        )
        .onAppear { viewModel.send(.onAppear) }
        .onChange(of: viewModel.updateCount) { onUpdated() }
        .onChange(of: viewModel.isDeleted) { _, isDeleted in
            if isDeleted { onDeleted() }
        }
    }
}

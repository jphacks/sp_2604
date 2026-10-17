import SwiftUI

/// 場所を検索して 1 件選ぶシート。選んだ場所は `onSelect` で呼び出し元に返す。
struct PlaceSearchScreen: View {
    let onSelect: (Place) -> Void

    @State private var viewModel = PlaceSearchViewModel()

    var body: some View {
        PlaceSearchContent(
            query: viewModel.query,
            places: viewModel.places,
            onSelect: onSelect,
            send: viewModel.send
        )
    }
}

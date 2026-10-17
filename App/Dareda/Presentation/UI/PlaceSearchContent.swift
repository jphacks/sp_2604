import SwiftUI

struct PlaceSearchContent: View {
    let query: String
    let places: [Place]
    let onSelect: (Place) -> Void
    let send: (PlaceSearchViewModel.Action) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(places, id: \.self) { place in
                Button {
                    onSelect(place)
                    dismiss()
                } label: {
                    Label(place.name, systemImage: "mappin.and.ellipse")
                }
                .accessibilityIdentifier("placeSearch.result")
            }
            .overlay {
                if places.isEmpty, !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(
                text: Binding(get: { query }, set: { send(.queryChanged($0)) }),
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "場所を検索"
            )
            .navigationTitle("会った場所")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", role: .cancel) { dismiss() }
                        .accessibilityIdentifier("placeSearch.cancelButton")
                }
            }
        }
    }
}

#Preview {
    PlaceSearchContent(
        query: "札幌",
        places: [Place(name: "札幌駅", latitude: 43.0687, longitude: 141.3508)],
        onSelect: { _ in },
        send: { _ in }
    )
}

import SwiftUI

/// 会った場所 (任意) の表示と、選択・変更・解除の操作。検索シートの表示は呼び出し元が持つ。
struct PlacePicker: View {
    let place: Place?
    let onSelectTapped: () -> Void
    let onClearTapped: () -> Void

    var body: some View {
        if let place {
            HStack {
                Button(action: onSelectTapped) {
                    LabeledContent("場所") {
                        Text(place.name)
                            .accessibilityIdentifier("placePicker.placeName")
                    }
                }
                .accessibilityIdentifier("placePicker.changeButton")
                Button("場所を解除", systemImage: "xmark.circle.fill", action: onClearTapped)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("placePicker.clearButton")
            }
        } else {
            Button("場所を選択", systemImage: "mappin.and.ellipse", action: onSelectTapped)
                .accessibilityIdentifier("placePicker.selectButton")
        }
    }
}

#Preview {
    Form {
        PlacePicker(place: nil, onSelectTapped: {}, onClearTapped: {})
        PlacePicker(
            place: Place(name: "札幌駅", latitude: 43.0687, longitude: 141.3508),
            onSelectTapped: {},
            onClearTapped: {}
        )
    }
}

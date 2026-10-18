import SwiftUI

/// プロフィールの編集フォーム。名前・所属と、前回の会話の日時・場所・要約を編集する。
struct ProfileEditContent: View {
    let name: String
    let affiliation: String
    let metAt: Date
    let place: Place?
    let summary: String
    let isPlaceSearchPresented: Bool
    let canSave: Bool
    let isProcessing: Bool
    let send: (ProfileDetailViewModel.Action) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("相手") {
                    TextField("名前 (必須)", text: Binding(get: { name }, set: { send(.nameChanged($0)) }))
                        .accessibilityIdentifier("profileEdit.nameTextField")
                    TextField("所属", text: Binding(get: { affiliation }, set: { send(.affiliationChanged($0)) }))
                        .accessibilityIdentifier("profileEdit.affiliationTextField")
                }
                Section("前回の会話の日時・場所") {
                    DatePicker("日時", selection: Binding(get: { metAt }, set: { send(.metAtChanged($0)) }))
                        .accessibilityIdentifier("profileEdit.metAtPicker")
                    PlacePicker(
                        place: place,
                        onSelectTapped: { send(.placeSelectButtonTapped) },
                        onClearTapped: { send(.placeClearButtonTapped) }
                    )
                }
                Section("前回の会話の要約") {
                    TextField(
                        "要約",
                        text: Binding(get: { summary }, set: { send(.summaryChanged($0)) }),
                        axis: .vertical
                    )
                    .lineLimit(3...10)
                    .accessibilityIdentifier("profileEdit.summaryTextField")
                }
            }
            .navigationTitle("プロフィールを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { send(.editPresentedChanged(false)) }
                        .accessibilityIdentifier("profileEdit.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Button(role: .confirm) { send(.editSaveButtonTapped) }
                            .disabled(!canSave)
                            .accessibilityIdentifier("profileEdit.saveButton")
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { isPlaceSearchPresented },
                set: { send(.placeSearchPresentedChanged($0)) }
            )) {
                PlaceSearchScreen { send(.placeSelected($0)) }
            }
        }
    }
}

#Preview {
    ProfileEditContent(
        name: "山田 太郎", affiliation: "株式会社サンプル",
        metAt: Date(timeIntervalSince1970: 1_700_000_000),
        place: Place(name: "渋谷駅", latitude: 35.658, longitude: 139.701),
        summary: "新規事業について話した",
        isPlaceSearchPresented: false, canSave: true, isProcessing: false, send: { _ in }
    )
}

import SwiftUI

struct RegistrationContent: View {
    let name: String
    let affiliation: String
    let metAt: Date
    let place: Place?
    let summary: String
    let isPlaceSearchPresented: Bool
    let isSaving: Bool
    let canSave: Bool
    let saveErrorMessage: LocalizedStringResource?
    let send: (RegistrationViewModel.Action) -> Void

    var body: some View {
        Form {
            Section("相手") {
                TextField("名前 (必須)", text: Binding(get: { name }, set: { send(.nameChanged($0)) }))
                    .accessibilityIdentifier("registration.nameTextField")
                TextField("所属", text: Binding(get: { affiliation }, set: { send(.affiliationChanged($0)) }))
                    .accessibilityIdentifier("registration.affiliationTextField")
            }
            Section("会った日時・場所") {
                DatePicker("日時", selection: Binding(get: { metAt }, set: { send(.metAtChanged($0)) }))
                    .accessibilityIdentifier("registration.metAtPicker")
                PlacePicker(
                    place: place,
                    onSelectTapped: { send(.placeSelectButtonTapped) },
                    onClearTapped: { send(.placeClearButtonTapped) }
                )
            }
            Section("会話の要約") {
                TextField(
                    "要約",
                    text: Binding(get: { summary }, set: { send(.summaryChanged($0)) }),
                    axis: .vertical
                )
                .lineLimit(3...10)
                .accessibilityIdentifier("registration.summaryTextField")
            }
            if let saveErrorMessage {
                Section {
                    Text(saveErrorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("registration.saveError")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button(role: .confirm) {
                        send(.saveButtonTapped)
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("registration.saveButton")
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

#Preview("入力中") {
    NavigationStack {
        RegistrationContent(
            name: "山田 太郎", affiliation: "株式会社サンプル", metAt: .now,
            place: Place(name: "札幌駅", latitude: 43.0687, longitude: 141.3508),
            summary: "新規事業について話した。", isPlaceSearchPresented: false,
            isSaving: false, canSave: true, saveErrorMessage: nil, send: { _ in }
        )
    }
}

#Preview("保存失敗") {
    NavigationStack {
        RegistrationContent(
            name: "山田 太郎", affiliation: "", metAt: .now, place: nil, summary: "要約",
            isPlaceSearchPresented: false, isSaving: false, canSave: true,
            saveErrorMessage: "保存できませんでした。もう一度お試しください。", send: { _ in }
        )
    }
}

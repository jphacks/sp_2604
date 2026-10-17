import SwiftUI

struct RegistrationContent: View {
    let name: String
    let affiliation: String
    let metAt: Date
    let place: Place?
    let summary: String
    let isSummarizing: Bool
    let summaryErrorMessage: LocalizedStringResource?
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
                if isSummarizing {
                    ProgressView("要約中")
                        .accessibilityIdentifier("registration.summarizing")
                } else {
                    TextField(
                        "要約",
                        text: Binding(get: { summary }, set: { send(.summaryChanged($0)) }),
                        axis: .vertical
                    )
                    .lineLimit(3...10)
                    .accessibilityIdentifier("registration.summaryTextField")
                }
                if let summaryErrorMessage {
                    Text(summaryErrorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("registration.summaryError")
                    Button("要約を再試行") { send(.summaryRetryButtonTapped) }
                        .accessibilityIdentifier("registration.summaryRetryButton")
                }
            }
            Section {
                Button {
                    send(.saveButtonTapped)
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(saveErrorMessage == nil ? "保存" : "もう一度保存")
                    }
                }
                .disabled(!canSave)
                .accessibilityIdentifier("registration.saveButton")
                if let saveErrorMessage {
                    Text(saveErrorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("registration.saveError")
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
            summary: "新規事業について話した。", isSummarizing: false, summaryErrorMessage: nil,
            isPlaceSearchPresented: false, isSaving: false, canSave: true, saveErrorMessage: nil,
            send: { _ in }
        )
    }
}

#Preview("要約中") {
    NavigationStack {
        RegistrationContent(
            name: "", affiliation: "", metAt: .now, place: nil, summary: "", isSummarizing: true,
            summaryErrorMessage: nil, isPlaceSearchPresented: false, isSaving: false, canSave: false,
            saveErrorMessage: nil, send: { _ in }
        )
    }
}

#Preview("保存失敗") {
    NavigationStack {
        RegistrationContent(
            name: "山田 太郎", affiliation: "", metAt: .now, place: nil, summary: "要約", isSummarizing: false,
            summaryErrorMessage: nil, isPlaceSearchPresented: false, isSaving: false, canSave: true,
            saveErrorMessage: "保存できませんでした。もう一度お試しください。", send: { _ in }
        )
    }
}

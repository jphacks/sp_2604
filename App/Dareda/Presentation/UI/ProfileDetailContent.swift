import SwiftUI

struct ProfileDetailContent: View {
    let detail: ProfileDetailServiceModel?
    let isEditPresented: Bool
    let name: String
    let affiliation: String
    let metAt: Date
    let place: Place?
    let summary: String
    let isPlaceSearchPresented: Bool
    let canSave: Bool
    let isDeleteConfirmationPresented: Bool
    let isProcessing: Bool
    let errorMessage: LocalizedStringResource?
    let send: (ProfileDetailViewModel.Action) -> Void

    var body: some View {
        Form {
            if let detail {
                Section {
                    Text(detail.profile.name)
                        .accessibilityIdentifier("profileDetail.name")
                    if !detail.profile.affiliation.isEmpty {
                        Text(detail.profile.affiliation)
                            .accessibilityIdentifier("profileDetail.affiliation")
                    }
                }
                if let encounter = detail.encounter {
                    Section("前回の会話") {
                        Text(encounter.metAt.formatted(date: .abbreviated, time: .shortened))
                            .accessibilityIdentifier("profileDetail.metAt")
                        if let place = encounter.place {
                            Text(place.name)
                                .accessibilityIdentifier("profileDetail.place")
                        }
                        if !encounter.summary.isEmpty {
                            Text(encounter.summary)
                                .accessibilityIdentifier("profileDetail.summary")
                        }
                    }
                }
                Section {
                    Button("削除", role: .destructive) { send(.deleteButtonTapped) }
                        .disabled(isProcessing)
                        .accessibilityIdentifier("profileDetail.deleteButton")
                }
            }
        }
        .navigationTitle(detail?.profile.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("編集") { send(.editButtonTapped) }
                    .disabled(detail == nil)
                    .accessibilityIdentifier("profileDetail.editButton")
            }
        }
        .sheet(isPresented: Binding(get: { isEditPresented }, set: { send(.editPresentedChanged($0)) })) {
            ProfileEditContent(
                name: name, affiliation: affiliation, metAt: metAt, place: place, summary: summary,
                isPlaceSearchPresented: isPlaceSearchPresented, canSave: canSave,
                isProcessing: isProcessing, send: send
            )
        }
        .confirmationDialog(
            "このプロフィールを削除しますか?",
            isPresented: Binding(
                get: { isDeleteConfirmationPresented },
                set: { send(.deleteConfirmationPresentedChanged($0)) }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) { send(.deleteConfirmed) }
                .accessibilityIdentifier("profileDetail.deleteConfirmButton")
        } message: {
            Text("出会いの記録も一緒に削除されます。この操作は取り消せません。")
        }
        .alert(
            "エラー",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { send(.errorAlertDismissed) } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("OK") {}
                .accessibilityIdentifier("profileDetail.errorAlertOKButton")
        } message: { message in
            Text(message)
        }
    }
}

#Preview {
    let profile = Profile(id: UUID(), name: "山田 太郎", affiliation: "株式会社サンプル", vector: [])
    NavigationStack {
        ProfileDetailContent(
            detail: ProfileDetailServiceModel(
                profile: profile,
                encounter: Encounter(
                    id: UUID(),
                    profileID: profile.id,
                    summary: "新規事業について話した",
                    metAt: Date(timeIntervalSince1970: 1_700_000_000),
                    place: Place(name: "渋谷駅", latitude: 35.658, longitude: 139.701)
                )
            ),
            isEditPresented: false,
            name: "",
            affiliation: "",
            metAt: Date(timeIntervalSince1970: 1_700_000_000),
            place: nil,
            summary: "",
            isPlaceSearchPresented: false,
            canSave: false,
            isDeleteConfirmationPresented: false,
            isProcessing: false,
            errorMessage: nil,
            send: { _ in }
        )
    }
}

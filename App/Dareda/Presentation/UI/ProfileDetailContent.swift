import SwiftUI

struct ProfileDetailContent: View {
    let detail: ProfileDetailServiceModel?
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
                    Section("初回の出会い") {
                        if !encounter.summary.isEmpty {
                            Text(encounter.summary)
                                .accessibilityIdentifier("profileDetail.summary")
                        }
                        Text(encounter.metAt.formatted(date: .abbreviated, time: .shortened))
                            .accessibilityIdentifier("profileDetail.metAt")
                        if let place = encounter.place {
                            Text(place.name)
                                .accessibilityIdentifier("profileDetail.place")
                        }
                    }
                }
            }
        }
        .navigationTitle(detail?.profile.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
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
                    metAt: .now,
                    place: Place(name: "渋谷駅", latitude: 35.658, longitude: 139.701)
                )
            ),
            send: { _ in }
        )
    }
}

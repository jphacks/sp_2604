import SwiftUI

struct ProfileListContent<Actions: View>: View {
    let profiles: [Profile]
    let path: [Profile.ID]
    let send: (ProfileListViewModel.Action) -> Void
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        NavigationStack(
            path: Binding(get: { path }, set: { send(.pathChanged($0)) })
        ) {
            List(profiles) { profile in
                NavigationLink(value: profile.id) {
                    ProfileRow(profile: profile)
                }
                .accessibilityIdentifier("profileList.row.\(profile.name)")
            }
            .overlay {
                if profiles.isEmpty {
                    Text("まだ誰も登録されていません")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("profileList.emptyLabel")
                }
            }
            .navigationTitle("プロフィール")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) { actions() }
            }
            .navigationDestination(for: Profile.ID.self) { id in
                ProfileDetailScreen(
                    profileID: id,
                    onUpdated: { send(.profileUpdated) },
                    onDeleted: { send(.profileDeleted) }
                )
            }
        }
    }
}

#Preview {
    ProfileListContent(
        profiles: [
            Profile(id: UUID(), name: "山田 太郎", affiliation: "株式会社サンプル", vector: []),
            Profile(id: UUID(), name: "佐藤 花子", affiliation: "", vector: []),
        ],
        path: [],
        send: { _ in },
        actions: { EmptyView() }
    )
}

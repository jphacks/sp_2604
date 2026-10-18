import SwiftUI

struct ProfileDetailContent: View {
    let profile: WatchProfile

    var body: some View {
        List {
            Section {
                Text(profile.name)
                if !profile.affiliation.isEmpty {
                    Text(profile.affiliation)
                        .foregroundStyle(.secondary)
                }
            }
            if profile.summary != nil || profile.metAt != nil {
                Section("前回の会話") {
                    if let summary = profile.summary, !summary.isEmpty {
                        Text(summary)
                    }
                    if let metAt = profile.metAt {
                        Text(metAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let placeName = profile.placeName {
                        Text(placeName)
                    }
                }
            }
        }
        .navigationTitle(profile.name)
    }
}

#Preview {
    NavigationStack {
        ProfileDetailContent(
            profile: WatchProfile(
                id: UUID(),
                name: "山田 太郎",
                affiliation: "株式会社サンプル",
                summary: "新規事業について話した",
                metAt: .now,
                placeName: "渋谷駅"
            )
        )
    }
}

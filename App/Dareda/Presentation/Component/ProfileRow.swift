import SwiftUI

struct ProfileRow: View {
    let profile: Profile

    var body: some View {
        VStack(alignment: .leading) {
            Text(profile.name)
                .font(.headline)
            if !profile.affiliation.isEmpty {
                Text(profile.affiliation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ProfileRow(profile: Profile(id: UUID(), name: "山田 太郎", affiliation: "株式会社サンプル", vector: []))
}

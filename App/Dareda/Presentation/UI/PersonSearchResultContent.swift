import SwiftUI

/// 人物検索の結果。最も声が近い 1 人を表示し、該当なしなら新規登録に進ませる。
/// 相手の発話が足りない場合は、追加録音か、追加せずに手動で選ぶかを選ばせる。
struct PersonSearchResultContent: View {
    /// 類似度の高い順の候補。相手の発話が足りないときは `nil`。
    let candidates: [ProfileDetailServiceModel]?
    let insufficientPartnerSpeechDuration: TimeInterval?
    let isConfirming: Bool
    let send: (ProcessingViewModel.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let insufficientPartnerSpeechDuration {
                insufficientSpeech(insufficientPartnerSpeechDuration)
            } else if let candidates {
                if candidates.isEmpty {
                    Text("登録済みの人物がいません")
                        .font(.headline)
                        .accessibilityIdentifier("personSearch.noProfilesNotice")
                    Button("新規登録に進む", systemImage: "person.badge.plus") { send(.newRegistrationButtonTapped) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("personSearch.newRegistrationButton")
                } else {
                    candidateList(candidates)
                }
            }
        }
        .disabled(isConfirming)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func insufficientSpeech(_ duration: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("相手の声が足りません").font(.headline)
                Text("相手の発話が\(Int(ProvisionalParameters.partnerMinimumSpeechDuration))秒に足りないため、照合できません。もう少し会話を録音して追加するか、保存済みのプロフィールから選んでください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("personSearch.insufficientSpeechNotice")
            Button("追加で録音する", systemImage: "mic") { send(.additionalRecordingButtonTapped) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("personSearch.additionalRecordingButton")
            Button("追加せずに選ぶ", systemImage: "list.bullet") { send(.manualSelectionButtonTapped) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("personSearch.skipAdditionalRecordingButton")
        }
    }

    private func candidateList(_ candidates: [ProfileDetailServiceModel]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("この人ではありませんか？").font(.headline)
            if let candidate = candidates.first {
                PersonSearchCandidateRow(candidate: candidate)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("personSearch.candidate")
            }
            Button("該当なし・新規登録", systemImage: "person.badge.plus") { send(.newRegistrationButtonTapped) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("personSearch.newRegistrationButton")
        }
    }
}

/// 候補 1 件。未登録の情報は表示しない。
private struct PersonSearchCandidateRow: View {
    let candidate: ProfileDetailServiceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProfileRow(profile: candidate.profile)
            if let encounter = candidate.encounter {
                Text(encounter.metAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                if let place = encounter.place {
                    Label(place.name, systemImage: "mappin.and.ellipse")
                        .font(.footnote)
                }
                if !encounter.summary.isEmpty {
                    Text(encounter.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.fill.tertiary, in: .rect(cornerRadius: 12))
    }
}

/// 保存済みのプロフィールから手動で選ぶ。
struct PersonSearchManualSelectionContent: View {
    let profiles: [Profile]
    let send: (ProcessingViewModel.Action) -> Void

    var body: some View {
        NavigationStack {
            List {
                if profiles.isEmpty {
                    Text("登録済みの人物がいません")
                        .accessibilityIdentifier("personSearch.manualSelection.empty")
                }
                ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                    Button { send(.candidateSelected(profile.id)) } label: {
                        ProfileRow(profile: profile)
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("personSearch.manualSelection.\(index)")
                }
            }
            .navigationTitle("人物を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { send(.manualSelectionPresentedChanged(false)) }
                        .accessibilityIdentifier("personSearch.manualSelection.closeButton")
                }
            }
        }
    }
}

#Preview("候補") {
    let profile = Profile(id: UUID(), name: "山田 太郎", affiliation: "株式会社サンプル", vector: [])
    ScrollView {
        PersonSearchResultContent(
            candidates: [
                ProfileDetailServiceModel(
                    profile: profile,
                    encounter: Encounter(
                        id: UUID(), profileID: profile.id, summary: "新規事業について話した", metAt: .now,
                        place: Place(name: "渋谷駅", latitude: 35.658, longitude: 139.701)
                    )
                ),
                ProfileDetailServiceModel(
                    profile: Profile(id: UUID(), name: "佐藤 花子", affiliation: "", vector: []), encounter: nil
                ),
            ],
            insufficientPartnerSpeechDuration: nil, isConfirming: false, send: { _ in }
        )
        .padding(24)
    }
}

#Preview("登録0人") {
    PersonSearchResultContent(candidates: [], insufficientPartnerSpeechDuration: nil, isConfirming: false, send: { _ in })
        .padding(24)
}

#Preview("発話不足") {
    PersonSearchResultContent(candidates: nil, insufficientPartnerSpeechDuration: 5, isConfirming: false, send: { _ in })
        .padding(24)
}

#Preview("手動選択") {
    PersonSearchManualSelectionContent(
        profiles: [Profile(id: UUID(), name: "山田 太郎", affiliation: "株式会社サンプル", vector: [])],
        send: { _ in }
    )
}

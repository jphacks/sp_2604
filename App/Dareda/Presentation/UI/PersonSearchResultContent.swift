import SwiftUI

/// 人物検索の結果。最も声が近い 1 人を表示し、該当なしなら新規登録に進ませる。
/// 相手の発話が足りない場合は、追加録音か、追加せずに手動で選ぶかを選ばせる。
struct PersonSearchResultContent: View {
    /// 類似度の高い順の候補。相手の発話が足りないときは `nil`。
    let candidates: [ProfileDetailServiceModel]?
    let insufficientPartnerSpeechDuration: TimeInterval?
    let isConfirming: Bool
    var canOverwrite = false
    /// 候補の提示後に今回の会話の要約を作成中。
    var isSummarizing = false
    /// 今回の会話の日時と要約。要約は作成が済むまで `nil`。
    var latestMetAt: Date?
    var latestSummary: String?
    var isOverwriteConfirmationPresented = false
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
            if isSummarizing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("今回の会話の要約を作成しています")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("personSearch.summarizingNotice")
            }
            if canOverwrite, let latestSummary, let candidate = candidates.first {
                Text("前回の会話を今回の内容で更新しますか？").font(.headline)
                LatestConversationCard(metAt: latestMetAt, summary: latestSummary)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("personSearch.latestConversation")
                Button("今回の内容で上書き", systemImage: "arrow.triangle.2.circlepath") {
                    send(.overwriteButtonTapped(candidate.profile.id))
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("personSearch.overwriteButton")
                .confirmationDialog(
                    "前回の会話を上書きしますか？",
                    isPresented: Binding(
                        get: { isOverwriteConfirmationPresented },
                        set: { send(.overwriteConfirmationPresentedChanged($0)) }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("上書きする", role: .destructive) { send(.overwriteConfirmed(candidate.profile.id)) }
                        .accessibilityIdentifier("personSearch.overwriteConfirmButton")
                } message: {
                    Text("前回の日時・要約を今回の会話で置き換えます。場所は未設定になり、元に戻せません。")
                }
            }
            Button("該当なし・新規登録", systemImage: "person.badge.plus") { send(.newRegistrationButtonTapped) }
                .buttonStyle(.bordered)
                .disabled(isSummarizing)
                .accessibilityIdentifier("personSearch.newRegistrationButton")
        }
    }
}

/// 今回の会話の日時と要約。上書きの提案に表示する。
private struct LatestConversationCard: View {
    let metAt: Date?
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今回の会話").font(.subheadline.bold())
            if let metAt {
                Text(metAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
            }
            if !summary.isEmpty {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.fill.tertiary, in: .rect(cornerRadius: 12))
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
                        id: UUID(), profileID: profile.id, summary: "新規事業について話した",
                        metAt: Date(timeIntervalSince1970: 1_700_000_000),
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

#Preview("要約作成中・上書きの提案") {
    let profile = Profile(id: UUID(), name: "山田 太郎", affiliation: "株式会社サンプル", vector: [])
    let candidates = [
        ProfileDetailServiceModel(
            profile: profile,
            encounter: Encounter(
                id: UUID(), profileID: profile.id, summary: "新規事業について話した",
                metAt: Date(timeIntervalSince1970: 1_700_000_000),
                place: Place(name: "渋谷駅", latitude: 35.658, longitude: 139.701)
            )
        )
    ]
    ScrollView {
        VStack(spacing: 32) {
            PersonSearchResultContent(
                candidates: candidates, insufficientPartnerSpeechDuration: nil, isConfirming: false,
                isSummarizing: true, latestMetAt: Date(timeIntervalSince1970: 1_700_100_000), send: { _ in }
            )
            PersonSearchResultContent(
                candidates: candidates, insufficientPartnerSpeechDuration: nil, isConfirming: false,
                canOverwrite: true, latestMetAt: Date(timeIntervalSince1970: 1_700_100_000),
                latestSummary: "来月の打ち合わせ日程を決めた", send: { _ in }
            )
        }
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

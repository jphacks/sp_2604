import SwiftUI

/// iPhone で処理中の録音の状況。候補の確定・本人の選択・新規登録もここから行える。
struct ProcessingSection: View {
    let state: WatchProcessingState
    let additionalRecordTapped: () -> Void
    let send: (WatchCommand) -> Void

    var body: some View {
        switch state {
        case let .processing(stage):
            Section("iPhone で処理中") {
                HStack {
                    ProgressView()
                        .frame(width: 24)
                    Text(stage.label)
                }
                cancelButton
            }
        case let .candidates(candidates):
            Section {
                if candidates.isEmpty {
                    Text("該当する人が見つかりませんでした")
                }
                ForEach(candidates) { candidate in
                    Button { send(.selectCandidate(candidate.id)) } label: {
                        ProfileRow(profile: candidate)
                    }
                    .accessibilityIdentifier("watch.candidate")
                }
                Button { send(.startNewRegistration) } label: {
                    Label("該当なし・新規登録", systemImage: "person.badge.plus")
                }
                .accessibilityIdentifier("watch.newRegistrationButton")
                cancelButton
            } header: {
                Text("この人ですか?")
            }
        case .needsAdditionalRecording:
            Section {
                Text("相手の声が足りません。もう少し会話を録音してください。")
                Button(action: additionalRecordTapped) {
                    Label("追加で録音", systemImage: "mic.badge.plus")
                }
                cancelButton
            }
        case let .selectSelf(speakers):
            Section {
                ForEach(speakers) { speaker in
                    Button { send(.selectSelf(speaker.id)) } label: {
                        Text(speaker.speeches.prefix(2).joined(separator: "\n"))
                            .lineLimit(4)
                    }
                    .accessibilityIdentifier("watch.speaker")
                }
                cancelButton
            } header: {
                Text("あなたの発言はどれですか?")
            }
        case let .registration(draft):
            Section {
                NavigationLink {
                    RegistrationScreen(draft: draft, send: send)
                } label: {
                    Label("新規登録", systemImage: "person.badge.plus")
                }
                .accessibilityIdentifier("watch.registrationLink")
                cancelButton
            } header: {
                Text("新しい人を登録")
            }
        case .needsInputOnPhone:
            Section {
                Label("iPhone で続きの操作をしてください", systemImage: "iphone")
            }
        case let .failed(message):
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                Button { send(.retryProcessing) } label: {
                    Label("再試行", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("watch.retryButton")
                cancelButton
            }
        case let .completed(profile):
            Section {
                if let profile {
                    NavigationLink(value: profile) {
                        Label(profile.name, systemImage: "checkmark.circle")
                    }
                } else {
                    Label("登録しました", systemImage: "checkmark.circle")
                }
            }
        }
    }

    private var cancelButton: some View {
        Button("キャンセル", role: .destructive) { send(.cancelProcessing) }
    }
}

extension WatchProcessingStage {
    var label: LocalizedStringResource {
        switch self {
        case .transcribing: "文字起こし中"
        case .identifyingSpeakers: "話者を識別中"
        case .summarizing: "要約中"
        }
    }
}

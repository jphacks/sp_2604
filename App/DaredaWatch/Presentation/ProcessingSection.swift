import SwiftUI

/// iPhone で処理中の録音の状況。人物検索の候補はここから確定できる。
struct ProcessingSection: View {
    let state: WatchProcessingState
    let additionalRecordTapped: () -> Void
    let candidateSelected: (UUID) -> Void
    let cancelTapped: () -> Void

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
                    Text("該当する人が見つかりませんでした。新規登録は iPhone で行えます。")
                }
                ForEach(candidates) { candidate in
                    Button { candidateSelected(candidate.id) } label: {
                        ProfileRow(profile: candidate)
                    }
                    .accessibilityIdentifier("watch.candidate")
                }
                cancelButton
            } header: {
                Text("この人ですか?")
            } footer: {
                Text("該当しない場合は iPhone で新規登録できます")
            }
        case .needsAdditionalRecording:
            Section {
                Text("相手の声が足りません。もう少し会話を録音してください。")
                Button(action: additionalRecordTapped) {
                    Label("追加で録音", systemImage: "mic.badge.plus")
                }
                cancelButton
            }
        case .needsInputOnPhone:
            Section {
                Label("iPhone で続きの操作をしてください", systemImage: "iphone")
            }
        case let .failed(message):
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
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
        Button("キャンセル", role: .destructive, action: cancelTapped)
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

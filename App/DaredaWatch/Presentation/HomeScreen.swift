import SwiftUI

/// 録音ボタン・iPhone での処理状況・プロフィール一覧を表示する。
struct HomeScreen: View {
    @Environment(PhoneSession.self) private var phoneSession
    @Environment(WatchRecorder.self) private var recorder
    @State private var isRecordingPresented = false
    @State private var isAdditionalRecording = false

    var body: some View {
        NavigationStack {
            HomeContent(
                snapshot: phoneSession.snapshot,
                pendingTransferCount: phoneSession.pendingTransferCount,
                recordTapped: { startRecording(isAdditional: false) },
                additionalRecordTapped: { startRecording(isAdditional: true) },
                candidateSelected: { phoneSession.send(.selectCandidate($0)) },
                cancelTapped: { phoneSession.send(.cancelProcessing) }
            )
            .navigationDestination(for: WatchProfile.self) { ProfileDetailContent(profile: $0) }
        }
        .fullScreenCover(isPresented: $isRecordingPresented) {
            RecordingScreen()
        }
        .alert(
            "録音できません",
            isPresented: Binding(
                get: { if case .failed = recorder.state { true } else { false } },
                set: { if !$0 { recorder.dismissError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            if case let .failed(message) = recorder.state { Text(message) }
        }
    }

    private func startRecording(isAdditional: Bool) {
        Task {
            await recorder.start { url, startedAt in
                // 録音は iPhone に送り、文字起こし以降の処理は iPhone で行う
                phoneSession.transferRecording(url, startedAt: startedAt, isAdditional: isAdditional)
            }
            isRecordingPresented = recorder.isRecording
        }
    }
}

struct HomeContent: View {
    let snapshot: WatchSnapshot
    let pendingTransferCount: Int
    let recordTapped: () -> Void
    let additionalRecordTapped: () -> Void
    let candidateSelected: (UUID) -> Void
    let cancelTapped: () -> Void

    var body: some View {
        List {
            Section {
                Button(action: recordTapped) {
                    Label("録音", systemImage: "mic.fill")
                }
                .disabled(!snapshot.isRecordingAvailable || snapshot.processing != nil && !isProcessingDone)
                .accessibilityIdentifier("watch.recordButton")
            } footer: {
                if pendingTransferCount > 0 {
                    Text("録音を iPhone に送信しています")
                } else if !snapshot.isRecordingAvailable {
                    Text("iPhone で Dareda を開き、録音できる状態にしてください")
                }
            }

            if let processing = snapshot.processing {
                ProcessingSection(
                    state: processing,
                    additionalRecordTapped: additionalRecordTapped,
                    candidateSelected: candidateSelected,
                    cancelTapped: cancelTapped
                )
            }

            Section("会った人") {
                if snapshot.profiles.isEmpty {
                    Text("まだ登録されていません")
                        .foregroundStyle(.secondary)
                }
                ForEach(snapshot.profiles) { profile in
                    NavigationLink(value: profile) {
                        ProfileRow(profile: profile)
                    }
                }
            }
        }
        .navigationTitle("Dareda")
    }

    /// 処理が終わり、次の録音を始められるか。
    private var isProcessingDone: Bool {
        switch snapshot.processing {
        case .completed, .failed, nil: true
        default: false
        }
    }
}

struct ProfileRow: View {
    let profile: WatchProfile

    var body: some View {
        VStack(alignment: .leading) {
            Text(profile.name)
            if !profile.affiliation.isEmpty {
                Text(profile.affiliation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension WatchProfile: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview("処理なし") {
    NavigationStack {
        HomeContent(
            snapshot: WatchSnapshot(
                profiles: [WatchProfile(id: UUID(), name: "山田 太郎", affiliation: "株式会社サンプル")],
                isRecordingAvailable: true,
                processing: nil
            ),
            pendingTransferCount: 0,
            recordTapped: {},
            additionalRecordTapped: {},
            candidateSelected: { _ in },
            cancelTapped: {}
        )
    }
}

#Preview("候補") {
    NavigationStack {
        HomeContent(
            snapshot: WatchSnapshot(
                profiles: [],
                isRecordingAvailable: true,
                processing: .candidates([WatchProfile(id: UUID(), name: "山田 太郎", affiliation: "株式会社サンプル")])
            ),
            pendingTransferCount: 0,
            recordTapped: {},
            additionalRecordTapped: {},
            candidateSelected: { _ in },
            cancelTapped: {}
        )
    }
}

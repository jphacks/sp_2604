import SwiftUI

struct ProcessingContent: View {
    let stages: [(stage: ConversationAnalysisStage, status: ProcessingViewModel.StageStatus)]
    let errorMessage: LocalizedStringResource?
    let canRetry: Bool
    let isCompleted: Bool
    var isSuspended = false
    var selfSelectionAnalysis: ConversationAnalysis?
    let isCancelConfirmationPresented: Bool
    var registrationSource: RegistrationViewModel.Source?
    var searchCandidates: [ProfileDetailServiceModel]?
    var isConfirming = false
    var canOverwrite = false
    var isSummarizing = false
    var latestMetAt: Date?
    var latestSummary: String?
    var isOverwriteConfirmationPresented = false
    let send: (ProcessingViewModel.Action) -> Void

    var body: some View {
        Group {
            if let registrationSource {
                RegistrationScreen(source: registrationSource) { send(.registrationSaved($0)) }
            } else {
                ScrollView {
                    VStack(spacing: 28) {
                        // 残り時間・進捗率は表示しない
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(stages, id: \.stage) { item in
                                ProcessingStageRow(stage: item.stage, status: item.status)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("processing.errorNotice")
                            if canRetry {
                                Button("再試行", systemImage: "arrow.clockwise") { send(.retryButtonTapped) }
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityIdentifier("processing.retryButton")
                            }
                        }
                        if isSuspended {
                            Text("解析が中断されました。アプリに戻ると続きから再開します。")
                                .accessibilityIdentifier("processing.suspendedNotice")
                        }
                        if let selfSelectionAnalysis {
                            SelfSpeakerSelectionContent(analysis: selfSelectionAnalysis, send: send)
                        }
                        if searchCandidates != nil {
                            PersonSearchResultContent(
                                candidates: searchCandidates,
                                isConfirming: isConfirming,
                                canOverwrite: canOverwrite,
                                isSummarizing: isSummarizing,
                                latestMetAt: latestMetAt,
                                latestSummary: latestSummary,
                                isOverwriteConfirmationPresented: isOverwriteConfirmationPresented,
                                send: send
                            )
                        }
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle(registrationSource != nil ? "新規登録" : "人物を探す")
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .cancel) { send(.cancelButtonTapped) }
                    .accessibilityIdentifier("processing.cancelButton")
                    // iPad ではポップオーバーの起点になるため、トリガーのボタンに付ける
                    .confirmationDialog(
                        "処理をキャンセルしますか？",
                        isPresented: Binding(
                            get: { isCancelConfirmationPresented },
                            set: { send(.cancelConfirmationChanged($0)) }
                        ),
                        titleVisibility: .visible
                    ) {
                        Button("キャンセルする", role: .destructive) { send(.cancelConfirmed) }
                            .accessibilityIdentifier("processing.confirmDiscardButton")
                        Button("続ける", role: .cancel) { send(.cancelConfirmationChanged(false)) }
                            .accessibilityIdentifier("processing.cancelDiscardButton")
                    } message: {
                        Text("録音と処理中のデータは削除され、元に戻せません。")
                    }
            }
        }
    }
}

/// 本人を自動判定できなかったときに、話者ごとの発言から本人 (利用者自身) を選ばせる。
private struct SelfSpeakerSelectionContent: View {
    let analysis: ConversationAnalysis
    let send: (ProcessingViewModel.Action) -> Void

    /// 発言のある話者 (話し始めた順)。
    private var speakers: [(speaker: AnalyzedSpeaker, speeches: [SpeechSegment])] {
        analysis.speakers
            .map { ($0, analysis.speeches(of: $0.id)) }
            .filter { !$0.1.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("どれがあなたの発言ですか？").font(.headline)
                Text("あなたの声を自動で判別できませんでした。あなたの発言を選ぶと、残りの話者を相手として処理を続けます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("processing.selfSelectionNotice")

            ForEach(Array(speakers.enumerated()), id: \.element.speaker.id) { index, item in
                VStack(alignment: .leading, spacing: 8) {
                    Text("話者\(index + 1)").font(.subheadline.bold())
                    ForEach(Array(item.speeches.enumerated()), id: \.offset) { _, speech in
                        Text(speech.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                    }
                    Button("この話者が自分") { send(.selfSpeakerSelected(item.speaker.id)) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("processing.selfCandidate.\(index)")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("判断できない場合は、録音し直すかキャンセルしてください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("録音し直す", systemImage: "mic") { send(.rerecordButtonTapped) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("processing.rerecordButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProcessingStageRow: View {
    let stage: ConversationAnalysisStage
    let status: ProcessingViewModel.StageStatus

    var body: some View {
        HStack(spacing: 12) {
            Group {
                switch status {
                case .waiting: Image(systemName: "circle").foregroundStyle(.secondary)
                case .processing: ProgressView()
                case .completed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .failed: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                }
            }
            .frame(width: 24)
            Text(stage.label)
                .foregroundStyle(status == .waiting ? .secondary : .primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(statusLabel)
        .accessibilityIdentifier("processing.stage.\(identifier)")
    }

    private var statusLabel: String {
        switch status {
        case .waiting: "待機中"
        case .processing: "処理中"
        case .completed: "完了"
        case .failed: "失敗"
        }
    }

    private var identifier: String {
        switch stage {
        case .transcribing: "transcribing"
        case .identifyingSpeakers: "identifyingSpeakers"
        case .summarizing: "summarizing"
        }
    }
}

#Preview("処理中") {
    NavigationStack {
        ProcessingContent(
            stages: [(.transcribing, .completed), (.identifyingSpeakers, .processing), (.summarizing, .waiting)],
            errorMessage: nil, canRetry: false, isCompleted: false,
            isCancelConfirmationPresented: false, send: { _ in }
        )
    }
}

#Preview("失敗") {
    NavigationStack {
        ProcessingContent(
            stages: [(.transcribing, .completed), (.identifyingSpeakers, .failed), (.summarizing, .waiting)],
            errorMessage: "処理に失敗しました。もう一度お試しください。", canRetry: true,
            isCompleted: false,
            isCancelConfirmationPresented: false, send: { _ in }
        )
    }
}

#Preview("本人の手動選択") {
    NavigationStack {
        ProcessingContent(
            stages: [(.transcribing, .completed), (.identifyingSpeakers, .completed), (.summarizing, .waiting)],
            errorMessage: nil, canRetry: false, isCompleted: false,
            selfSelectionAnalysis: ConversationAnalysis(
                speeches: [
                    AttributedSpeech(segment: SpeechSegment(text: "はじめまして、田中です。", startTime: 0, endTime: 2), speakerID: "S1"),
                    AttributedSpeech(segment: SpeechSegment(text: "よろしくお願いします。", startTime: 2, endTime: 4), speakerID: "S2"),
                ],
                speakers: [
                    AnalyzedSpeaker(id: "S1", segments: [], embedding: nil),
                    AnalyzedSpeaker(id: "S2", segments: [], embedding: nil),
                ],
                selfSpeakerID: nil
            ),
            isCancelConfirmationPresented: false, send: { _ in }
        )
    }
}

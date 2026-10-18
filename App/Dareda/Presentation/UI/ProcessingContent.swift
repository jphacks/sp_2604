import SwiftUI

struct ProcessingContent: View {
    let stages: [(stage: ConversationAnalysisStage, status: ProcessingViewModel.StageStatus)]
    let errorMessage: LocalizedStringResource?
    let canRetry: Bool
    let isCompleted: Bool
    var isSuspended = false
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


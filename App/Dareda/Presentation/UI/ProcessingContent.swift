import SwiftUI

struct ProcessingContent: View {
    let mode: RecordingViewModel.Mode
    let stages: [(stage: ConversationAnalysisStage, status: ProcessingViewModel.StageStatus)]
    let errorMessage: LocalizedStringResource?
    let canRetry: Bool
    let isCompleted: Bool
    var isSuspended = false
    let needsSelfSelection: Bool
    let isCancelConfirmationPresented: Bool
    let send: (ProcessingViewModel.Action) -> Void

    var body: some View {
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
                // 完了後・本人未確定時の画面は #17 / #21 / #23 で置き換える
                if needsSelfSelection {
                    Text("本人の声を判別できませんでした。")
                        .accessibilityIdentifier("processing.selfSelectionNotice")
                }
                if isCompleted {
                    Text(mode == .registration ? "解析が完了しました" : "照合が完了しました")
                        .font(.headline)
                        .accessibilityIdentifier("processing.completedNotice")
                }
            }
            .padding(24)
        }
        .navigationTitle(mode == .registration ? "新規登録" : "人物を探す")
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { send(.cancelButtonTapped) }
                    .accessibilityIdentifier("processing.cancelButton")
            }
        }
        .sheet(isPresented: Binding(
            get: { isCancelConfirmationPresented },
            set: { send(.cancelConfirmationChanged($0)) }
        )) {
            CancelConfirmation(
                title: "処理をキャンセルしますか？",
                message: "録音と処理中のデータは削除され、元に戻せません。",
                confirmTitle: "キャンセルする",
                keepTitle: "続ける",
                identifierPrefix: "processing",
                onConfirm: { send(.cancelConfirmed) },
                onKeep: { send(.cancelConfirmationChanged(false)) }
            )
            .presentationDetents([.medium])
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
            mode: .registration,
            stages: [(.transcribing, .completed), (.identifyingSpeakers, .processing), (.summarizing, .waiting)],
            errorMessage: nil, canRetry: false, isCompleted: false, needsSelfSelection: false,
            isCancelConfirmationPresented: false, send: { _ in }
        )
    }
}

#Preview("失敗") {
    NavigationStack {
        ProcessingContent(
            mode: .search,
            stages: [(.transcribing, .completed), (.identifyingSpeakers, .failed)],
            errorMessage: "処理に失敗しました。もう一度お試しください。", canRetry: true,
            isCompleted: false, needsSelfSelection: false,
            isCancelConfirmationPresented: false, send: { _ in }
        )
    }
}

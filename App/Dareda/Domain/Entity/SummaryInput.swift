import Foundation

/// 要約に使う言語モデル。
nonisolated enum SummarizationModel: Sendable, Equatable {
    /// 端末上の言語モデル。
    case onDevice
    /// Private Cloud Compute の言語モデル。
    case privateCloud
}

/// 要約の入力。長い会話は分割して部分ごとに要約し、その要約をさらにまとめる。
nonisolated enum SummaryInput: Sendable, Equatable {
    /// 会話全体。
    case conversation(Transcript)
    /// 会話を分割した部分。`index` は 1 始まり。
    case conversationPart(Transcript, index: Int, count: Int)
    /// 部分ごとの要約。発話順に並べる。
    case partialSummaries([ConversationSummary])
}

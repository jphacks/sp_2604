import Foundation

/// 会話の話者。録音後に本人と相手が識別された状態を表す。
nonisolated enum Speaker: Sendable, Equatable {
    case me
    case other

    var label: String {
        switch self {
        case .me: "自分"
        case .other: "相手"
        }
    }
}

nonisolated struct TranscriptSegment: Sendable, Equatable {
    var speaker: Speaker
    var text: String
}

/// 話者ラベル付きの文字起こし。発話順に並べる。
nonisolated struct Transcript: Sendable, Equatable {
    var segments: [TranscriptSegment]

    /// 空白のみの発話を除いた発話。
    var meaningfulSegments: [TranscriptSegment] {
        segments.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var isEmpty: Bool {
        meaningfulSegments.isEmpty
    }

    /// 要約の入力に使う、1 発話 1 行の「話者: 発話」形式のテキスト。
    var labeledText: String {
        meaningfulSegments
            .map { "\($0.speaker.label): \($0.text.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n")
    }
}

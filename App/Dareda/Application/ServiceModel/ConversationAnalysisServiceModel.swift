import Foundation

/// 共通音声処理の処理状況。残り時間や進捗率は持たない。
nonisolated enum ConversationAnalysisStage: Sendable, Hashable {
    /// 文字起こし中
    case transcribing
    /// 話者識別中 (話者分離・話者ベクトル生成・本人照合)
    case identifyingSpeakers
    /// 要約中
    case summarizing

    var label: String {
        switch self {
        case .transcribing: "文字起こし中"
        case .identifyingSpeakers: "話者識別中"
        case .summarizing: "要約中"
        }
    }
}

nonisolated enum ConversationAnalysisEvent<Value: Sendable & Equatable>: Sendable, Equatable {
    /// 次の処理を開始した。
    case stageChanged(ConversationAnalysisStage)
    /// 全ての処理が完了した。ストリームはこの後終了する。
    case completed(Value)
}

/// 話者分離で分けた 1 人分の話者。
nonisolated struct AnalyzedSpeaker: Sendable, Equatable, Identifiable {
    let id: String
    /// この話者の発話区間 (開始時刻順)。
    var segments: [SpeakerSegment]
    /// 声の特徴ベクトル。発話が短すぎて生成できなかった場合は `nil` で、本人照合の対象外になる。
    var embedding: VoiceEmbedding?

    var speakingDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }
}

/// 話者を対応付けた文字起こしの 1 区間。
nonisolated struct AttributedSpeech: Sendable, Equatable {
    var segment: SpeechSegment
    /// 発話区間が最も重なる話者の ID。どの話者とも重ならない場合は `nil`。
    var speakerID: AnalyzedSpeaker.ID?
}

/// 第 1 段階の話者識別までを終えた解析結果。
nonisolated struct ConversationAnalysis: Sendable, Equatable {
    /// 話者を対応付けた文字起こし (発話順)。手動選択 UI ではこれを話者別に表示する。
    var speeches: [AttributedSpeech]
    var speakers: [AnalyzedSpeaker]
    /// 本人と判定した話者の ID (本人の声との類似度が最も高い話者)。
    var selfSpeakerID: AnalyzedSpeaker.ID

    /// 指定した話者の発言 (発話順)。
    func speeches(of speakerID: AnalyzedSpeaker.ID) -> [SpeechSegment] {
        speeches.filter { $0.speakerID == speakerID }.map(\.segment)
    }

    /// 指定した話者を本人、それ以外を相手とした話者ラベル付きの文字起こし。
    func transcript(selfSpeakerID: AnalyzedSpeaker.ID) -> Transcript {
        Transcript(
            segments: speeches.map {
                TranscriptSegment(speaker: $0.speakerID == selfSpeakerID ? .me : .other, text: $0.segment.text)
            }
        )
    }

    /// 本人以外でベクトルを持つ話者のうち、発話時間が最も長い話者 (1 対 1 の会話の相手)。
    /// 本人しか分離できなかった場合は `nil`。
    func partner(selfSpeakerID: AnalyzedSpeaker.ID) -> AnalyzedSpeaker? {
        speakers
            .filter { $0.id != selfSpeakerID && $0.embedding != nil }
            .max { $0.speakingDuration < $1.speakingDuration }
    }
}

nonisolated enum ConversationAnalysisError: Error, Equatable {
    /// 本人の声が登録されていない。
    case selfVoiceNotRegistered
    /// ベクトルを生成できた話者がいない (話者分離が不十分)。再録音またはキャンセルを促す。
    case noSpeakerDetected
    /// バックグラウンドでの実行を OS に打ち切られた。アプリに戻ったら同じセッションで呼び直し、未完了の処理だけを再試行する。
    case suspended
}

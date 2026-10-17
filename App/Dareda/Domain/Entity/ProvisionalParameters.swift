import Foundation

/// 実機検証 (#27) で確定する暫定値・しきい値。値の調整はこのファイルだけで行う。
nonisolated enum ProvisionalParameters {
    /// 本人の声の登録に必要な有効発話時間 (秒)。
    static let selfVoiceRequiredSpeechDuration: TimeInterval = 30
    /// 人物検索の照合に必要な相手の有効発話時間 (秒)。
    static let partnerMinimumSpeechDuration: TimeInterval = 10
    /// 1 回の録音の上限 (秒)。
    static let recordingMaxDuration: TimeInterval = 10 * 60
    /// 上限のどれだけ前に残り時間を案内するか (秒)。
    static let recordingWarningRemaining: TimeInterval = 60
    /// 本人識別 (第 1 段階) のコサイン類似度しきい値。これを超える話者がちょうど 1 人なら本人とする。
    static let selfIdentificationThreshold: Float = 0.5
    /// 人物検索で提示する候補の上限。
    static let personSearchCandidateLimit = 5
    /// 話者ベクトルを生成できる音声の最短長 (秒)。
    static let speakerEmbeddingMinimumDuration: TimeInterval = 0.5
    /// 話者分離で推定する話者数の下限。`nil` なら自動推定に任せる。
    /// 1 対 1 の会話が 1 人にまとめられると相手を識別できないため、2 人以上に分ける。
    static let diarizationMinimumSpeakers: Int? = 2
    /// 有効発話検出 (#7) の基準。
    static let speechQuality = SpeechQualityThresholds(
        frameDuration: 0.02,
        speechThresholdDB: -40
    )
}

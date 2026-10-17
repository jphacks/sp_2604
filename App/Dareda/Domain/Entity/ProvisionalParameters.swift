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
    /// 有効発話検出と音声品質判定 (#7) の基準。
    static let speechQuality = SpeechQualityThresholds(
        frameDuration: 0.02,
        speechThresholdDB: -40,
        minimumSpeechLevelDB: -30,
        clippingSampleLevel: 0.99,
        clippingRatio: 0.001
    )
}

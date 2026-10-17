import Foundation

nonisolated enum SpeechQualityIssue: Sendable, Equatable, Hashable {
    /// 音量不足
    case tooQuiet
    /// 音割れ
    case clipping
}

nonisolated struct SpeechQuality: Sendable, Equatable {
    /// 無音を除いた有効な発話時間 (秒)
    var effectiveSpeechDuration: TimeInterval
    var issues: Set<SpeechQualityIssue>

    var isAcceptable: Bool { issues.isEmpty }
}

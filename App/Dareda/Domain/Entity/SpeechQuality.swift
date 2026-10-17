import Foundation

nonisolated struct SpeechQuality: Sendable, Equatable {
    /// 無音を除いた有効な発話時間 (秒)
    var effectiveSpeechDuration: TimeInterval
}

import Foundation

/// 録音内の位置 (秒) を持つ文字起こしの 1 区間。話者分離結果との対応付けに使う。
nonisolated struct SpeechSegment: Sendable, Equatable, Codable {
    var text: String
    /// 録音先頭からの開始位置 (秒)。
    var startTime: TimeInterval
    /// 録音先頭からの終了位置 (秒)。
    var endTime: TimeInterval
}

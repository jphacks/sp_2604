import Foundation

/// 有効発話検出の閾値。実機検証で調整できるよう、すべて外から指定できる。
nonisolated struct SpeechQualityThresholds: Sendable, Equatable {
    /// 解析の 1 フレームの長さ (秒)
    var frameDuration: TimeInterval
    /// このレベル (dBFS) 以上のフレームを発話区間とみなす
    var speechThresholdDB: Float

    static let `default` = ProvisionalParameters.speechQuality
}

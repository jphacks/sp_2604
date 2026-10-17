import Foundation

/// 有効発話検出と音声品質判定の閾値。実機検証で調整できるよう、すべて外から指定できる。
nonisolated struct SpeechQualityThresholds: Sendable, Equatable {
    /// 解析の 1 フレームの長さ (秒)
    var frameDuration: TimeInterval
    /// このレベル (dBFS) 以上のフレームを発話区間とみなす
    var speechThresholdDB: Float
    /// 発話区間の平均レベル (dBFS) がこれを下回ると音量不足とする
    var minimumSpeechLevelDB: Float
    /// 絶対値がこれ以上のサンプルを音割れ (クリッピング) とみなす
    var clippingSampleLevel: Float
    /// 全サンプルに占める音割れサンプルの割合がこれ以上なら音割れとする
    var clippingRatio: Float

    static let `default` = ProvisionalParameters.speechQuality
}

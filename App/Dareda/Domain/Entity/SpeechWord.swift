import Foundation

/// 文字起こしの区間に含まれる、録音内の位置 (秒) を持つ単語。
/// 1 つの区間が話者の切り替わりをまたぐ場合に、単語単位で話者を対応付けるために使う。
nonisolated struct SpeechWord: Sendable, Equatable, Codable {
    var text: String
    /// 録音先頭からの開始位置 (秒)。
    var startTime: TimeInterval
    /// 録音先頭からの終了位置 (秒)。
    var endTime: TimeInterval
}

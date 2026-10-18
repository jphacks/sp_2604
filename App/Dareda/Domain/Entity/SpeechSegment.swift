import Foundation

/// 録音内の位置 (秒) を持つ文字起こしの 1 区間。話者分離結果との対応付けに使う。
nonisolated struct SpeechSegment: Sendable, Equatable, Codable {
    var text: String
    /// 録音先頭からの開始位置 (秒)。
    var startTime: TimeInterval
    /// 録音先頭からの終了位置 (秒)。
    var endTime: TimeInterval
    /// 区間内の単語 (発話順)。つなげると `text` になる。時刻を取得できなかった場合は空。
    var words: [SpeechWord]

    init(text: String, startTime: TimeInterval, endTime: TimeInterval, words: [SpeechWord] = []) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.words = words
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        startTime = try container.decode(TimeInterval.self, forKey: .startTime)
        endTime = try container.decode(TimeInterval.self, forKey: .endTime)
        // 単語を持たない以前の形式で保存された結果も読めるようにする
        words = try container.decodeIfPresent([SpeechWord].self, forKey: .words) ?? []
    }
}

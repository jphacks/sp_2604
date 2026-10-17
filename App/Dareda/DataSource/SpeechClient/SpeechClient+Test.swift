import Foundation
import Synchronization

nonisolated extension SpeechClient {
    /// 音声認識を使わないテストダブル。指定した区間をそのまま返す。
    /// `succeedsOnce` を指定すると 2 回目以降の文字起こしは失敗する (再実行されないことの検証用)。
    static func inMemory(
        segments: [(text: String, start: TimeInterval, end: TimeInterval)] = [
            (text: "こんにちは、はじめまして。", start: 0, end: 2.5),
            (text: "よろしくお願いします。", start: 2.5, end: 4),
        ],
        succeedsOnce: Bool = false
    ) -> SpeechClient {
        let callCount = Mutex(0)
        return SpeechClient(transcribe: { _, _ in
            let count = callCount.withLock { count in
                count += 1
                return count
            }
            if succeedsOnce, count > 1 { throw CocoaError(.fileReadUnknown) }
            return segments
        })
    }
}

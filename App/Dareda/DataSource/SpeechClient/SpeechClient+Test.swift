import Foundation
import Synchronization

nonisolated extension SpeechClient {
    /// 音声認識を使わないテストダブル。指定した区間をそのまま返す。
    /// `failsOnRetranscription` が `true` なら 2 回目以降の呼び出しで失敗する。
    static func inMemory(
        segments: [(text: String, start: TimeInterval, end: TimeInterval)] = [
            (text: "こんにちは、はじめまして。", start: 0, end: 2.5),
            (text: "よろしくお願いします。", start: 2.5, end: 4),
        ],
        failsOnRetranscription: Bool = false
    ) -> SpeechClient {
        let callCount = Mutex(0)
        return SpeechClient(transcribe: { _, _ in
            let count = callCount.withLock { value in
                value += 1
                return value
            }
            // 再試行で成功済みの文字起こしが再実行されたことを検出する
            if failsOnRetranscription, count > 1 { throw CocoaError(.featureUnsupported) }
            return segments
        })
    }
}

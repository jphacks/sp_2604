import Foundation

nonisolated extension SpeechClient {
    /// 音声認識を使わないテストダブル。指定した区間をそのまま返す。
    static func inMemory(
        segments: [(text: String, start: TimeInterval, end: TimeInterval)] = [
            (text: "こんにちは、はじめまして。", start: 0, end: 2.5),
            (text: "よろしくお願いします。", start: 2.5, end: 4),
        ]
    ) -> SpeechClient {
        SpeechClient(transcribe: { _, _ in segments })
    }
}

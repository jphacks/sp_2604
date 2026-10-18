nonisolated extension SpeechSynthesizerClient {
    /// 音を出さないテストダブル。`duration` だけ待ってから読み終わったことにする。
    static func inMemory(duration: Duration = .zero) -> SpeechSynthesizerClient {
        SpeechSynthesizerClient(
            speak: { _ in try? await Task.sleep(for: duration) }
        )
    }
}

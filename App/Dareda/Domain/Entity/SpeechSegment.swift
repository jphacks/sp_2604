import Foundation

/// 話者の声が含まれる音声区間。16kHz・モノラルの PCM サンプル (-1.0〜1.0) を保持する。
nonisolated struct SpeechSegment: Sendable, Equatable {
    static let sampleRate = 16_000

    var samples: [Float]

    var duration: TimeInterval {
        TimeInterval(samples.count) / TimeInterval(Self.sampleRate)
    }
}

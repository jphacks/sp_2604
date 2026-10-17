import Dependencies
import Foundation

nonisolated extension AudioFileClient {
    /// 指定したサンプルをそのまま返すテストダブル
    static func inMemory(sampleRate: Double, samples: [Float]) -> AudioFileClient {
        AudioFileClient(
            readSamples: { _ in (sampleRate, samples) }
        )
    }
}

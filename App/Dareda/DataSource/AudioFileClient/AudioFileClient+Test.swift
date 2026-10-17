import Dependencies
import Foundation

nonisolated extension AudioFileClient {
    /// 指定したサンプルをそのまま返すテストダブル
    static func inMemory(sampleRate: Double, samples: [Float]) -> AudioFileClient {
        AudioFileClient(
            readSamples: { _ in (sampleRate, samples) }
        )
    }

    /// 指定した長さ・振幅の正弦波 (16kHz) を発話として返すテストダブル
    static func speech(seconds: Int, amplitude: Float) -> AudioFileClient {
        let sampleRate = 16_000
        let samples = (0..<(sampleRate * seconds)).map { index in
            amplitude * sin(2 * .pi * 220 * Float(index) / Float(sampleRate))
        }
        return .inMemory(sampleRate: Double(sampleRate), samples: samples)
    }
}

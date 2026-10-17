import Dependencies
import Foundation

nonisolated extension AudioFileClient {
    /// 指定したサンプルをそのまま返すテストダブル
    static func inMemory(sampleRate: Double, samples: [Float]) -> AudioFileClient {
        AudioFileClient(
            readSamples: { _ in (sampleRate, samples) },
            duration: { _ in sampleRate > 0 ? Double(samples.count) / sampleRate : 0 }
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

    /// 本人 (前半 15 秒の正弦波) と相手 (後半 20 秒の、直流成分で声の特徴をずらした正弦波) の会話 (16kHz) を返すテストダブル
    static func conversation() -> AudioFileClient {
        let sampleRate = 16_000
        let samples = (0..<(sampleRate * 35)).map { index in
            let wave = 0.3 * sin(2 * .pi * 220 * Float(index) / Float(sampleRate))
            return index < sampleRate * 15 ? wave : wave - 200
        }
        return .inMemory(sampleRate: Double(sampleRate), samples: samples)
    }
}

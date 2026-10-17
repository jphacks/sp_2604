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

    /// 前半 15 秒を大きい声 (本人)、後半 15 秒を小さい声 (相手) とした 2 人の会話を返すテストダブル。
    static func conversation() -> AudioFileClient {
        let sampleRate = 16_000
        let samples = (0..<(sampleRate * 30)).map { index in
            let amplitude: Float = index < sampleRate * 15 ? 0.3 : 0.1
            return amplitude * sin(2 * .pi * 220 * Float(index) / Float(sampleRate))
        }
        return .inMemory(sampleRate: Double(sampleRate), samples: samples)
    }
}

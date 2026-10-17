import Foundation

nonisolated struct AudioSamples: Sendable, Equatable {
    var sampleRate: Double
    /// -1.0 ... 1.0 に正規化したモノラルのサンプル列
    var samples: [Float]
}

nonisolated extension AudioSamples {
    /// `startTime`〜`endTime` 秒の区間を、話者ベクトルの入力形式 (16kHz) に変換して切り出す。
    func voiceSegment(from startTime: TimeInterval, to endTime: TimeInterval) -> VoiceSegment {
        guard sampleRate > 0, !samples.isEmpty else { return VoiceSegment(samples: []) }
        let targetRate = Double(VoiceSegment.sampleRate)
        let count = max(0, Int((endTime - startTime) * targetRate))
        var result: [Float] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            // 線形補間でリサンプリングする
            let position = (startTime + Double(index) / targetRate) * sampleRate
            let lower = Int(position)
            guard lower >= 0, lower < samples.count else { break }
            let upper = min(lower + 1, samples.count - 1)
            let fraction = Float(position - Double(lower))
            result.append(samples[lower] + (samples[upper] - samples[lower]) * fraction)
        }
        return VoiceSegment(samples: result)
    }
}

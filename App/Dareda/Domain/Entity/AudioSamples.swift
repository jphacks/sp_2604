import Foundation

nonisolated struct AudioSamples: Sendable, Equatable {
    var sampleRate: Double
    /// -1.0 ... 1.0 に正規化したモノラルのサンプル列
    var samples: [Float]
}

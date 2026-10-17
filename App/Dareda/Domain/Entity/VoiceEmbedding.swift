import Foundation

/// 声の特徴を表すベクトル (話者埋め込み)。長さ 1 に正規化されている。
nonisolated struct VoiceEmbedding: Sendable, Equatable, Codable {
    /// 正規化済みのベクトル。`SelfVoice.vector` や `Profile.vector` にはこの値を保存する。
    var values: [Float]

    /// 値を正規化して生成する。長さが 0 のベクトルは `nil`。
    init?(normalizing raw: [Float]) {
        let norm = raw.reduce(0) { $0 + $1 * $1 }.squareRoot()
        guard norm > 0 else { return nil }
        values = raw.map { $0 / norm }
    }

    /// 保存済みの正規化済みベクトルから復元する。
    init(values: [Float]) {
        self.values = values
    }

    /// コサイン類似度 (-1.0〜1.0)。大きいほど同じ声に近い。次元が異なる場合は `nil`。
    func cosineSimilarity(to other: VoiceEmbedding) -> Float? {
        guard values.count == other.values.count, !values.isEmpty else { return nil }
        var dot: Float = 0
        var lhs: Float = 0
        var rhs: Float = 0
        for (a, b) in zip(values, other.values) {
            dot += a * b
            lhs += a * a
            rhs += b * b
        }
        let denominator = (lhs * rhs).squareRoot()
        guard denominator > 0 else { return nil }
        return dot / denominator
    }
}

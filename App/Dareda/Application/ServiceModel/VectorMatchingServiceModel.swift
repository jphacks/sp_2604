import Foundation

/// 人物検索 (第 2 段階) の照合結果の 1 件。
nonisolated struct ProfileMatch: Sendable, Equatable, Identifiable {
    var profileID: Profile.ID
    /// 確信度。コサイン類似度をそのまま使う (-1...1)。
    var similarity: Float

    var id: Profile.ID { profileID }
}

nonisolated enum VectorMatchingError: Error, Equatable {
    case emptyVector
    case dimensionMismatch
    case zeroNorm
}

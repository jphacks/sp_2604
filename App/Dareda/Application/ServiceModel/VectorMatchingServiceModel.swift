import Foundation

/// 人物検索 (第 2 段階) の照合結果の 1 件。
nonisolated struct ProfileMatch: Sendable, Equatable, Identifiable {
    var profileID: Profile.ID
    /// 確信度。コサイン類似度をそのまま使う (-1...1)。
    var similarity: Float

    var id: Profile.ID { profileID }
}

/// 本人識別 (第 1 段階) の判定結果。
nonisolated enum SelfIdentification: Sendable, Equatable {
    /// しきい値を超えた話者がちょうど 1 人。引数は `speakers` 内のインデックス。
    case identified(index: Int)
    /// しきい値を超えた話者が 0 人または複数。ユーザーによる手動選択が必要。引数はしきい値を超えた話者のインデックス。
    case ambiguous(candidates: [Int])
}

nonisolated enum VectorMatchingError: Error, Equatable {
    case emptyVector
    case dimensionMismatch
    case zeroNorm
}

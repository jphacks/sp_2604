import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct VectorMatchingService: Sendable {
    /// 2 つのベクトルのコサイン類似度 (-1...1) を返す。空・次元不一致・ゼロベクトルは throws。
    var cosineSimilarity: @Sendable (_ lhs: [Float], _ rhs: [Float]) throws -> Float
    /// 本人識別 (第 1 段階)。`threshold` を超える話者がちょうど 1 人なら本人と判定する。
    var identifySelf: @Sendable (
        _ speakers: [[Float]], _ selfVector: [Float], _ threshold: Float
    ) throws -> SelfIdentification
    /// 人物検索 (第 2 段階)。しきい値なしで類似度の高い順に上位 `limit` 件を返す。
    var rankProfiles: @Sendable (
        _ query: [Float], _ profiles: [Profile], _ limit: Int
    ) throws -> [ProfileMatch]
}

nonisolated extension VectorMatchingService {
    /// 本人識別のしきい値。
    static let defaultSelfIdentificationThreshold = ProvisionalParameters.selfIdentificationThreshold
    /// 人物検索で提示する候補の上限。
    static let defaultMatchLimit = ProvisionalParameters.personSearchCandidateLimit
}

nonisolated extension VectorMatchingService: DependencyKey {
    static let liveValue: VectorMatchingService = {
        let impl = VectorMatchingServiceImpl()
        return VectorMatchingService(
            cosineSimilarity: impl.cosineSimilarity(_:_:),
            identifySelf: impl.identifySelf(_:_:_:),
            rankProfiles: impl.rankProfiles(_:_:_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var vectorMatchingService: VectorMatchingService {
        get { self[VectorMatchingService.self] }
        set { self[VectorMatchingService.self] = newValue }
    }
}

private nonisolated struct VectorMatchingServiceImpl: Sendable {
    func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) throws -> Float {
        guard !lhs.isEmpty, !rhs.isEmpty else { throw VectorMatchingError.emptyVector }
        guard lhs.count == rhs.count else { throw VectorMatchingError.dimensionMismatch }
        var dot: Float = 0
        var lhsNorm: Float = 0
        var rhsNorm: Float = 0
        for (l, r) in zip(lhs, rhs) {
            dot += l * r
            lhsNorm += l * l
            rhsNorm += r * r
        }
        guard lhsNorm > 0, rhsNorm > 0 else { throw VectorMatchingError.zeroNorm }
        return dot / (lhsNorm.squareRoot() * rhsNorm.squareRoot())
    }

    func identifySelf(
        _ speakers: [[Float]], _ selfVector: [Float], _ threshold: Float
    ) throws -> SelfIdentification {
        var passed: [Int] = []
        for (index, speaker) in speakers.enumerated()
        where try cosineSimilarity(speaker, selfVector) > threshold {
            passed.append(index)
        }
        if passed.count == 1 { return .identified(index: passed[0]) }
        return .ambiguous(candidates: passed)
    }

    func rankProfiles(
        _ query: [Float], _ profiles: [Profile], _ limit: Int
    ) throws -> [ProfileMatch] {
        let matches = try profiles.map {
            ProfileMatch(profileID: $0.id, similarity: try cosineSimilarity(query, $0.vector))
        }
        return Array(matches.sorted { $0.similarity > $1.similarity }.prefix(max(limit, 0)))
    }
}

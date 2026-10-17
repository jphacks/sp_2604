import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct SpeakerEmbeddingService: Sendable {
    /// 音声区間 (複数可) から声の特徴ベクトルを生成する。本人の登録・相手の識別・人物検索で共通して使う。
    var embedding: @Sendable (_ segments: [VoiceSegment]) async throws -> VoiceEmbedding
}

nonisolated extension SpeakerEmbeddingService: DependencyKey {
    static let liveValue: SpeakerEmbeddingService = {
        let impl = SpeakerEmbeddingServiceImpl()
        return SpeakerEmbeddingService(
            embedding: impl.embedding(of:)
        )
    }()
}

nonisolated extension DependencyValues {
    var speakerEmbeddingService: SpeakerEmbeddingService {
        get { self[SpeakerEmbeddingService.self] }
        set { self[SpeakerEmbeddingService.self] = newValue }
    }
}

private nonisolated struct SpeakerEmbeddingServiceImpl: Sendable {
    @Dependency(\.speakerEmbeddingGateway) private var speakerEmbeddingGateway

    func embedding(of segments: [VoiceSegment]) async throws -> VoiceEmbedding {
        try await speakerEmbeddingGateway.embedding(segments)
    }
}

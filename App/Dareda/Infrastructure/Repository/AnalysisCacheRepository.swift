import Dependencies
import DependenciesMacros
import Foundation

/// 処理セッション内で成功した解析結果 (文字起こし・話者分離・話者ベクトル・要約) を一時保存する。
/// セッションディレクトリ以下に置くため、セッションの削除とともに消える。
@DependencyClient
nonisolated struct AnalysisCacheRepository: Sendable {
    var getSpeechSegments: @Sendable (_ session: ProcessingSession) async throws -> [SpeechSegment]?
    var setSpeechSegments: @Sendable (_ segments: [SpeechSegment], _ session: ProcessingSession) async throws -> Void
    var getSpeakerSegments: @Sendable (_ session: ProcessingSession) async throws -> [SpeakerSegment]?
    var setSpeakerSegments: @Sendable (_ segments: [SpeakerSegment], _ session: ProcessingSession) async throws -> Void
    /// 話者 ID ごとの話者ベクトル。ベクトルを生成できた話者のみ含む。
    var getSpeakerEmbeddings: @Sendable (_ session: ProcessingSession) async throws -> [String: VoiceEmbedding]?
    var setSpeakerEmbeddings: @Sendable (
        _ embeddings: [String: VoiceEmbedding], _ session: ProcessingSession
    ) async throws -> Void
    var getSummary: @Sendable (_ session: ProcessingSession) async throws -> ConversationSummary?
    var setSummary: @Sendable (_ summary: ConversationSummary, _ session: ProcessingSession) async throws -> Void
}

nonisolated extension AnalysisCacheRepository: DependencyKey {
    static let liveValue: AnalysisCacheRepository = {
        let impl = AnalysisCacheRepositoryImpl()
        return AnalysisCacheRepository(
            getSpeechSegments: impl.getSpeechSegments(_:),
            setSpeechSegments: impl.setSpeechSegments(_:_:),
            getSpeakerSegments: impl.getSpeakerSegments(_:),
            setSpeakerSegments: impl.setSpeakerSegments(_:_:),
            getSpeakerEmbeddings: impl.getSpeakerEmbeddings(_:),
            setSpeakerEmbeddings: impl.setSpeakerEmbeddings(_:_:),
            getSummary: impl.getSummary(_:),
            setSummary: impl.setSummary(_:_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var analysisCacheRepository: AnalysisCacheRepository {
        get { self[AnalysisCacheRepository.self] }
        set { self[AnalysisCacheRepository.self] = newValue }
    }
}

private nonisolated struct AnalysisCacheRepositoryImpl: Sendable {
    @Dependency(\.fileSystemClient) private var fileSystemClient

    func getSpeechSegments(_ session: ProcessingSession) async throws -> [SpeechSegment]? {
        try read(session, "speechSegments.json")
    }

    func setSpeechSegments(_ segments: [SpeechSegment], _ session: ProcessingSession) async throws {
        try write(segments, session, "speechSegments.json")
    }

    func getSpeakerSegments(_ session: ProcessingSession) async throws -> [SpeakerSegment]? {
        try read(session, "speakerSegments.json")
    }

    func setSpeakerSegments(_ segments: [SpeakerSegment], _ session: ProcessingSession) async throws {
        try write(segments, session, "speakerSegments.json")
    }

    func getSpeakerEmbeddings(_ session: ProcessingSession) async throws -> [String: VoiceEmbedding]? {
        try read(session, "speakerEmbeddings.json")
    }

    func setSpeakerEmbeddings(_ embeddings: [String: VoiceEmbedding], _ session: ProcessingSession) async throws {
        try write(embeddings, session, "speakerEmbeddings.json")
    }

    func getSummary(_ session: ProcessingSession) async throws -> ConversationSummary? {
        try read(session, "summary.json")
    }

    func setSummary(_ summary: ConversationSummary, _ session: ProcessingSession) async throws {
        try write(summary, session, "summary.json")
    }

    private func read<Value: Decodable>(_ session: ProcessingSession, _ fileName: String) throws -> Value? {
        let url = session.directoryURL.appendingPathComponent(fileName)
        guard let data = try fileSystemClient.readData(url) else { return nil }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    private func write<Value: Encodable>(_ value: Value, _ session: ProcessingSession, _ fileName: String) throws {
        let url = session.directoryURL.appendingPathComponent(fileName)
        try fileSystemClient.writeData(JSONEncoder().encode(value), url)
    }
}

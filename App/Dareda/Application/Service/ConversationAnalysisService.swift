import Dependencies
import DependenciesMacros
import Foundation

/// 録音後の共通音声処理 (文字起こし・話者分離・話者ベクトル生成・本人識別・要約)。新規登録・人物検索の両方で使う。
///
/// 成功した処理の結果はセッションに保存し、同じセッションで再度呼ばれたときは再実行しない。
/// 失敗・中断後に同じセッションで呼び直すと、未完了の処理だけを実行する。時間を理由に打ち切らない。
/// バックグラウンドに移行しても処理を続け、OS に打ち切られたら `ConversationAnalysisError.suspended` で終了する。
@DependencyClient
nonisolated struct ConversationAnalysisService: Sendable {
    /// 第 1 段階の話者識別までを行う。処理状況を流し、最後に `.completed` で結果を流して終了する。
    var analyze: @Sendable (
        _ recording: Recording, _ session: ProcessingSession
    ) -> AsyncThrowingStream<ConversationAnalysisEvent<ConversationAnalysis>, any Error> = { _, _ in
        AsyncThrowingStream { $0.finish() }
    }
    /// 本人を確定した文字起こしから会話の要約を生成する (新規登録時のみ)。
    var summarize: @Sendable (
        _ transcript: Transcript, _ session: ProcessingSession
    ) -> AsyncThrowingStream<ConversationAnalysisEvent<ConversationSummary>, any Error> = { _, _ in
        AsyncThrowingStream { $0.finish() }
    }
}

nonisolated extension ConversationAnalysisService: DependencyKey {
    static let liveValue: ConversationAnalysisService = {
        let impl = ConversationAnalysisServiceImpl()
        return ConversationAnalysisService(
            analyze: impl.analyze(_:session:),
            summarize: impl.summarize(_:session:)
        )
    }()
}

nonisolated extension DependencyValues {
    var conversationAnalysisService: ConversationAnalysisService {
        get { self[ConversationAnalysisService.self] }
        set { self[ConversationAnalysisService.self] = newValue }
    }
}

private nonisolated struct ConversationAnalysisServiceImpl: Sendable {
    @Dependency(\.analysisCacheRepository) private var analysisCacheRepository
    @Dependency(\.selfVoiceRepository) private var selfVoiceRepository
    @Dependency(\.transcriptionService) private var transcriptionService
    @Dependency(\.speakerDiarizationGateway) private var speakerDiarizationGateway
    @Dependency(\.speakerEmbeddingGateway) private var speakerEmbeddingGateway
    @Dependency(\.audioFileGateway) private var audioFileGateway
    @Dependency(\.conversationSummaryService) private var conversationSummaryService
    @Dependency(\.vectorMatchingService) private var vectorMatchingService
    @Dependency(\.backgroundExecutionGateway) private var backgroundExecutionGateway

    func analyze(
        _ recording: Recording, session: ProcessingSession
    ) -> AsyncThrowingStream<ConversationAnalysisEvent<ConversationAnalysis>, any Error> {
        stream { continuation in
            continuation.yield(.stageChanged(.transcribing))
            let speechSegments = try await speechSegments(recording, session)

            continuation.yield(.stageChanged(.identifyingSpeakers))
            guard let selfVoice = try await selfVoiceRepository.get() else {
                throw ConversationAnalysisError.selfVoiceNotRegistered
            }
            let speakerSegments = try await speakerSegments(recording, session)
            let embeddings = try await speakerEmbeddings(recording, speakerSegments, session)

            let speakers = Dictionary(grouping: speakerSegments, by: \.speakerID)
                .map { AnalyzedSpeaker(id: $0.key, segments: $0.value, embedding: embeddings[$0.key]) }
                .sorted { ($0.segments.first?.startTime ?? 0) < ($1.segments.first?.startTime ?? 0) }
            let candidates = speakers.filter { $0.embedding != nil }
            guard !candidates.isEmpty else { throw ConversationAnalysisError.noSpeakerDetected }

            let identification = try vectorMatchingService.identifySelf(
                candidates.compactMap { $0.embedding?.values },
                selfVoice.vector,
                VectorMatchingService.defaultSelfIdentificationThreshold
            )
            let selfSpeakerID: AnalyzedSpeaker.ID? =
                if case let .identified(index) = identification { candidates[index].id } else { nil }

            return ConversationAnalysis(
                speeches: speechSegments.map {
                    AttributedSpeech(segment: $0, speakerID: Self.speakerID(overlapping: $0, in: speakerSegments))
                },
                speakers: speakers,
                selfSpeakerID: selfSpeakerID
            )
        }
    }

    func summarize(
        _ transcript: Transcript, session: ProcessingSession
    ) -> AsyncThrowingStream<ConversationAnalysisEvent<ConversationSummary>, any Error> {
        stream { continuation in
            if let cached = try await analysisCacheRepository.getSummary(session) { return cached }
            continuation.yield(.stageChanged(.summarizing))
            let summary = try await conversationSummaryService.summarize(transcript)
            try await analysisCacheRepository.setSummary(summary, session)
            return summary
        }
    }

    private func speechSegments(_ recording: Recording, _ session: ProcessingSession) async throws -> [SpeechSegment] {
        if let cached = try await analysisCacheRepository.getSpeechSegments(session) { return cached }
        let segments = try await transcriptionService.transcribe(recording.fileURL)
        try await analysisCacheRepository.setSpeechSegments(segments, session)
        return segments
    }

    private func speakerSegments(_ recording: Recording, _ session: ProcessingSession) async throws -> [SpeakerSegment] {
        if let cached = try await analysisCacheRepository.getSpeakerSegments(session) { return cached }
        let segments = try await speakerDiarizationGateway.diarize(recording.fileURL)
        try await analysisCacheRepository.setSpeakerSegments(segments, session)
        return segments
    }

    /// 話者ごとにベクトルを生成する。生成済みの話者は再生成しない。発話が短すぎる話者は結果に含めない。
    private func speakerEmbeddings(
        _ recording: Recording, _ speakerSegments: [SpeakerSegment], _ session: ProcessingSession
    ) async throws -> [String: VoiceEmbedding] {
        var embeddings = try await analysisCacheRepository.getSpeakerEmbeddings(session) ?? [:]
        let pending = Dictionary(grouping: speakerSegments, by: \.speakerID).filter { embeddings[$0.key] == nil }
        guard !pending.isEmpty else { return embeddings }

        let audio = try await audioFileGateway.samples(recording.fileURL)
        for (speakerID, segments) in pending.sorted(by: { $0.key < $1.key }) {
            let voiceSegments = segments.map { audio.voiceSegment(from: $0.startTime, to: $0.endTime) }
            do {
                embeddings[speakerID] = try await speakerEmbeddingGateway.embedding(voiceSegments)
            } catch SpeakerEmbeddingError.insufficientSpeech {
                continue
            }
            try await analysisCacheRepository.setSpeakerEmbeddings(embeddings, session)
        }
        return embeddings
    }

    /// 文字起こしの区間と最も長く重なる話者の ID。
    private static func speakerID(overlapping speech: SpeechSegment, in speakerSegments: [SpeakerSegment]) -> String? {
        var overlaps: [String: TimeInterval] = [:]
        for segment in speakerSegments {
            let overlap = min(speech.endTime, segment.endTime) - max(speech.startTime, segment.startTime)
            if overlap > 0 { overlaps[segment.speakerID, default: 0] += overlap }
        }
        return overlaps.max { $0.value < $1.value }?.key
    }

    private func stream<Value: Sendable & Equatable>(
        _ body: @escaping @Sendable (
            AsyncThrowingStream<ConversationAnalysisEvent<Value>, any Error>.Continuation
        ) async throws -> Value
    ) -> AsyncThrowingStream<ConversationAnalysisEvent<Value>, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                // バックグラウンドに移行しても続ける。OS に打ち切られたら中断として終了し、
                // ストリームの終了で処理もキャンセルする。完了済みの処理の結果はセッションに残る。
                let execution = await backgroundExecutionGateway.begin {
                    continuation.finish(throwing: ConversationAnalysisError.suspended)
                }
                do {
                    let value = try await body(continuation)
                    continuation.yield(.completed(value))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                await backgroundExecutionGateway.end(execution)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

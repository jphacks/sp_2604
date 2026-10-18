import Dependencies
import DependenciesMacros
import Foundation
import Logging

/// 録音後の共通音声処理 (文字起こし・話者分離・話者ベクトル生成・本人識別・要約)。新規登録・人物検索の両方で使う。
///
/// 成功した処理の結果はセッションに保存し、同じセッションで再度呼ばれたときは再実行しない。
/// 失敗・中断後に同じセッションで呼び直すと、未完了の処理だけを実行する。時間を理由に打ち切らない。
/// バックグラウンドに移行しても処理を続け、OS やユーザーに打ち切られたら `ConversationAnalysisError.suspended` で終了する。
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
    private static let logger = Logger(label: "Dareda.ConversationAnalysisService")

    @Dependency(\.analysisCacheRepository) private var analysisCacheRepository
    @Dependency(\.selfVoiceRepository) private var selfVoiceRepository
    @Dependency(\.transcriptionService) private var transcriptionService
    @Dependency(\.speakerDiarizationGateway) private var speakerDiarizationGateway
    @Dependency(\.speakerEmbeddingGateway) private var speakerEmbeddingGateway
    @Dependency(\.audioFileGateway) private var audioFileGateway
    @Dependency(\.conversationSummaryService) private var conversationSummaryService
    @Dependency(\.vectorMatchingService) private var vectorMatchingService
    @Dependency(\.backgroundExecutionGateway) private var backgroundExecutionGateway
    @Dependency(\.metricsGateway) private var metricsGateway
    @Dependency(\.date) private var date

    func analyze(
        _ recording: Recording, session: ProcessingSession
    ) -> AsyncThrowingStream<ConversationAnalysisEvent<ConversationAnalysis>, any Error> {
        stream(operation: "analysis") { report in
            Self.logger.debug("Transcription stage started")
            await report(.transcribing)
            let speechSegments = try await speechSegments(recording, session)

            Self.logger.debug("Speaker identification stage started")
            await report(.identifyingSpeakers)
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

            try recordSelfSimilarities(candidates, selfVoice)
            let selfIndex = try vectorMatchingService.identifySelf(
                candidates.compactMap { $0.embedding?.values },
                selfVoice.vector
            )
            let selfSpeakerID: AnalyzedSpeaker.ID? = candidates[selfIndex].id
            metricsGateway.recordValue("metrics.analysis.speakerCount", Double(speakers.count))
            metricsGateway.recordMemoryFootprint("metrics.analysis.memory")

            return ConversationAnalysis(
                speeches: Self.attributedSpeeches(speechSegments, speakerSegments),
                speakers: speakers,
                selfSpeakerID: selfSpeakerID
            )
        }
    }

    func summarize(
        _ transcript: Transcript, session: ProcessingSession
    ) -> AsyncThrowingStream<ConversationAnalysisEvent<ConversationSummary>, any Error> {
        stream(operation: "summary") { report in
            if let cached = try await analysisCacheRepository.getSummary(session) {
                Self.logger.debug("Reusing cached summary")
                return cached
            }
            Self.logger.debug("Summary generation started")
            await report(.summarizing)
            let start = date.now
            let summary = try await conversationSummaryService.summarize(transcript)
            metricsGateway.recordDuration("metrics.summary.duration", date.now.timeIntervalSince(start))
            metricsGateway.recordMemoryFootprint("metrics.summary.memory")
            try await analysisCacheRepository.setSummary(summary, session)
            return summary
        }
    }

    private func speechSegments(_ recording: Recording, _ session: ProcessingSession) async throws -> [SpeechSegment] {
        if let cached = try await analysisCacheRepository.getSpeechSegments(session) {
            Self.logger.debug("Reusing cached transcription")
            return cached
        }
        let start = date.now
        let segments = try await transcriptionService.transcribe(recording.fileURL)
        metricsGateway.recordDuration("metrics.transcription.duration", date.now.timeIntervalSince(start))
        try await analysisCacheRepository.setSpeechSegments(segments, session)
        return segments
    }

    private func speakerSegments(_ recording: Recording, _ session: ProcessingSession) async throws -> [SpeakerSegment] {
        if let cached = try await analysisCacheRepository.getSpeakerSegments(session) {
            Self.logger.debug("Reusing cached speaker diarization")
            return cached
        }
        let start = date.now
        let segments = try await speakerDiarizationGateway.diarize(recording.fileURL)
        metricsGateway.recordDuration("metrics.diarization.duration", date.now.timeIntervalSince(start))
        metricsGateway.recordMemoryFootprint("metrics.diarization.memory")
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

        let start = date.now
        defer { metricsGateway.recordDuration("metrics.embedding.duration", date.now.timeIntervalSince(start)) }
        let audio = try await audioFileGateway.samples(recording.fileURL)
        for (speakerID, segments) in pending.sorted(by: { $0.key < $1.key }) {
            let voiceSegments = segments.map { audio.voiceSegment(from: $0.startTime, to: $0.endTime) }
            do {
                embeddings[speakerID] = try await speakerEmbeddingGateway.embedding(voiceSegments)
            } catch SpeakerEmbeddingError.insufficientSpeech {
                Self.logger.notice("Skipping speaker embedding because speech is insufficient")
                continue
            }
            try await analysisCacheRepository.setSpeakerEmbeddings(embeddings, session)
        }
        return embeddings
    }

    /// 本人識別の検証用に、各話者と本人の声の類似度を記録する。
    private func recordSelfSimilarities(_ candidates: [AnalyzedSpeaker], _ selfVoice: SelfVoice) throws {
        var similarities: [(speakerID: AnalyzedSpeaker.ID, similarity: Float)] = []
        for candidate in candidates {
            guard let embedding = candidate.embedding else { continue }
            let similarity = try vectorMatchingService.cosineSimilarity(embedding.values, selfVoice.vector)
            metricsGateway.recordValue("metrics.selfIdentification.similarity", Double(similarity))
            similarities.append((candidate.id, similarity))
        }
        #if DEBUG
        // デバッグ時のみ、話者 ID と類似度の組み合わせを出力する
        let pairs = similarities
            .map { "\($0.speakerID)=\(String(format: "%.4f", $0.similarity))" }
            .joined(separator: ", ")
        Self.logger.debug("Speaker similarities", metadata: ["similarities": "\(pairs)"])
        #else
        let pairs = similarities.enumerated()
            .map { "speaker\($0.offset + 1)=\(String(format: "%.4f", $0.element.similarity))" }
            .joined(separator: ", ")
        Self.logger.info("Speaker similarities", metadata: ["similarities": "\(pairs)"])
        #endif
    }

    /// 文字起こしの区間に話者を対応付ける。
    /// 文字起こしの 1 区間は 10〜20 秒と長く、話者の切り替わりをまたぐことがあるため、
    /// 単語の時刻がある場合は単語ごとに話者を対応付け、話者が替わるところで区間を分ける。
    private static func attributedSpeeches(
        _ speeches: [SpeechSegment], _ speakerSegments: [SpeakerSegment]
    ) -> [AttributedSpeech] {
        speeches.flatMap { speech -> [AttributedSpeech] in
            // どの話者とも重ならない区間は、これまでどおり話者なしにする
            guard
                let speechSpeakerID = speakerID(from: speech.startTime, to: speech.endTime, in: speakerSegments),
                !speech.words.isEmpty
            else {
                return [AttributedSpeech(
                    segment: speech, speakerID: speakerID(from: speech.startTime, to: speech.endTime, in: speakerSegments)
                )]
            }

            var groups: [(speakerID: AnalyzedSpeaker.ID, words: [SpeechWord])] = []
            for word in speech.words {
                // 単語は短く、話者分離の区間の隙間に入ることがあるため、重ならなければ最も近い話者にする
                let wordSpeakerID = speakerID(from: word.startTime, to: word.endTime, in: speakerSegments)
                    ?? nearestSpeakerID(to: word, in: speakerSegments)
                    ?? speechSpeakerID
                if let last = groups.last, last.speakerID == wordSpeakerID {
                    groups[groups.count - 1].words.append(word)
                } else {
                    groups.append((wordSpeakerID, [word]))
                }
            }
            guard groups.count > 1 else { return [AttributedSpeech(segment: speech, speakerID: groups[0].speakerID)] }
            return groups.map { group in
                AttributedSpeech(
                    segment: SpeechSegment(
                        text: group.words.map(\.text).joined().trimmingCharacters(in: .whitespaces),
                        startTime: group.words[0].startTime,
                        endTime: group.words[group.words.count - 1].endTime,
                        words: group.words
                    ),
                    speakerID: group.speakerID
                )
            }
        }
    }

    /// 指定した区間と最も長く重なる話者の ID。どの話者とも重ならない場合は `nil`。
    private static func speakerID(
        from startTime: TimeInterval, to endTime: TimeInterval, in speakerSegments: [SpeakerSegment]
    ) -> AnalyzedSpeaker.ID? {
        var overlaps: [String: TimeInterval] = [:]
        for segment in speakerSegments {
            let overlap = min(endTime, segment.endTime) - max(startTime, segment.startTime)
            if overlap > 0 { overlaps[segment.speakerID, default: 0] += overlap }
        }
        return overlaps.max { $0.value < $1.value }?.key
    }

    /// 単語の中心時刻に最も近い発話区間の話者の ID。
    private static func nearestSpeakerID(to word: SpeechWord, in speakerSegments: [SpeakerSegment]) -> AnalyzedSpeaker.ID? {
        let center = (word.startTime + word.endTime) / 2
        func distance(_ segment: SpeakerSegment) -> TimeInterval {
            max(segment.startTime - center, center - segment.endTime, 0)
        }
        return speakerSegments.min { distance($0) < distance($1) }?.speakerID
    }

    private func stream<Value: Sendable & Equatable>(
        operation: String,
        _ body: @escaping @Sendable (
            _ report: @escaping @Sendable (ConversationAnalysisStage) async -> Void
        ) async throws -> Value
    ) -> AsyncThrowingStream<ConversationAnalysisEvent<Value>, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var logger = Self.logger
                logger[metadataKey: "operation"] = .string(operation)
                logger.info("Processing started")
                // BGContinuedProcessingTask でバックグラウンドに移行しても続ける。OS やユーザーに打ち切られたら中断として終了し、
                // ストリームの終了で処理もキャンセルする。完了済みの処理の結果はセッションに残る。
                let execution = await backgroundExecutionGateway.begin {
                    Self.logger.notice("Processing suspended by OS", metadata: ["operation": .string(operation)])
                    continuation.finish(throwing: ConversationAnalysisError.suspended)
                }
                do {
                    let value = try await body { stage in
                        continuation.yield(.stageChanged(stage))
                        await backgroundExecutionGateway.update(execution, stage)
                    }
                    logger.info("Processing completed")
                    continuation.yield(.completed(value))
                    continuation.finish()
                } catch {
                    if error is CancellationError || Task.isCancelled {
                        logger.debug("Processing cancelled")
                    } else {
                        logger.error("Processing failed", metadata: ["error_type": "\(type(of: error))"])
                    }
                    continuation.finish(throwing: error)
                }
                await backgroundExecutionGateway.end(execution)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

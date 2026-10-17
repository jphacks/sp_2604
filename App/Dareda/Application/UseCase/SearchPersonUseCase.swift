import Dependencies
import DependenciesMacros
import Foundation

/// 人物検索 (第 2 段階の話者識別)。相手の声を保存済みプロフィールと照合し、候補を類似度の高い順に返す。
///
/// 相手の有効発話が足りない場合は `.needsAdditionalRecording` を返す。追加録音したら、
/// 最初の録音とあわせて `recordings` に渡して呼び直すと、両方の相手の発話区間を結合して照合する。
/// しきい値は設けず、自動で確定もしない。
@DependencyClient
nonisolated struct SearchPersonUseCase: Sendable {
    var search: @Sendable (
        _ recordings: [PersonSearchRecording]
    ) -> AsyncThrowingStream<ConversationAnalysisEvent<PersonSearchResult>, any Error> = { _ in
        AsyncThrowingStream { $0.finish() }
    }
}

nonisolated extension SearchPersonUseCase {
    /// 照合に必要な相手の有効発話時間 (秒)。#27 の実機検証で確定する暫定値。
    static let minimumPartnerSpeechDuration: TimeInterval = 10
}

/// 人物検索に使う 1 回分の録音。解析結果はセッションごとに保存するため、録音ごとに別のセッションを渡す。
nonisolated struct PersonSearchRecording: Sendable, Equatable {
    var recording: Recording
    var session: ProcessingSession
}

nonisolated enum PersonSearchResult: Sendable, Equatable {
    /// 相手の有効発話が足りない。追加録音を促す。引数はこれまでの録音を合わせた相手の有効発話時間 (秒)。
    case needsAdditionalRecording(partnerSpeechDuration: TimeInterval)
    /// 類似度の高い順の候補。上位 5 件 (保存済みが 5 人未満なら全件)。
    case candidates([ProfileMatch])
}

nonisolated enum PersonSearchError: Error, Equatable {
    /// 本人を自動判定できなかった。手動選択 (#17) が必要。
    case selfNotIdentified
    /// 本人以外の話者を検出できなかった。
    case partnerNotDetected
}

nonisolated extension SearchPersonUseCase: DependencyKey {
    static let liveValue: SearchPersonUseCase = {
        let impl = SearchPersonUseCaseImpl()
        return SearchPersonUseCase(
            search: impl.search(_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var searchPersonUseCase: SearchPersonUseCase {
        get { self[SearchPersonUseCase.self] }
        set { self[SearchPersonUseCase.self] = newValue }
    }
}

private nonisolated struct SearchPersonUseCaseImpl: Sendable {
    @Dependency(\.conversationAnalysisService) private var conversationAnalysisService
    @Dependency(\.speechQualityService) private var speechQualityService
    @Dependency(\.vectorMatchingService) private var vectorMatchingService
    @Dependency(\.audioFileGateway) private var audioFileGateway
    @Dependency(\.speakerEmbeddingGateway) private var speakerEmbeddingGateway
    @Dependency(\.profileRepository) private var profileRepository

    func search(
        _ recordings: [PersonSearchRecording]
    ) -> AsyncThrowingStream<ConversationAnalysisEvent<PersonSearchResult>, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let result = try await search(recordings, continuation)
                    continuation.yield(.completed(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func search(
        _ recordings: [PersonSearchRecording],
        _ continuation: AsyncThrowingStream<ConversationAnalysisEvent<PersonSearchResult>, any Error>.Continuation
    ) async throws -> PersonSearchResult {
        var partnerSegments: [VoiceSegment] = []
        var partnerEmbedding: VoiceEmbedding?
        for target in recordings {
            let analysis = try await analyze(target, continuation)
            guard let selfSpeakerID = analysis.selfSpeakerID else { throw PersonSearchError.selfNotIdentified }
            // 本人の発話は含めない
            guard let partner = analysis.partner(selfSpeakerID: selfSpeakerID) else { continue }
            let audio = try await audioFileGateway.samples(target.recording.fileURL)
            partnerSegments += partner.segments.map { audio.voiceSegment(from: $0.startTime, to: $0.endTime) }
            partnerEmbedding = partner.embedding
        }
        guard !partnerSegments.isEmpty else { throw PersonSearchError.partnerNotDetected }

        // 無音を除いた有効発話時間で判定する
        let partnerAudio = AudioSamples(
            sampleRate: Double(VoiceSegment.sampleRate),
            samples: partnerSegments.flatMap(\.samples)
        )
        let partnerSpeechDuration = speechQualityService.analyze(partnerAudio, .default).effectiveSpeechDuration
        guard partnerSpeechDuration >= SearchPersonUseCase.minimumPartnerSpeechDuration else {
            return .needsAdditionalRecording(partnerSpeechDuration: partnerSpeechDuration)
        }

        // 追加録音がある場合は、全ての録音の相手の発話区間を結合してベクトルを生成し直す
        let query =
            if recordings.count == 1, let partnerEmbedding {
                partnerEmbedding
            } else {
                try await speakerEmbeddingGateway.embedding(partnerSegments)
            }
        let profiles = try await profileRepository.getAll()
        return .candidates(
            try vectorMatchingService.rankProfiles(query.values, profiles, VectorMatchingService.defaultMatchLimit)
        )
    }

    private func analyze(
        _ target: PersonSearchRecording,
        _ continuation: AsyncThrowingStream<ConversationAnalysisEvent<PersonSearchResult>, any Error>.Continuation
    ) async throws -> ConversationAnalysis {
        for try await event in conversationAnalysisService.analyze(target.recording, target.session) {
            switch event {
            case let .stageChanged(stage):
                continuation.yield(.stageChanged(stage))
            case let .completed(analysis):
                return analysis
            }
        }
        throw CancellationError()
    }
}

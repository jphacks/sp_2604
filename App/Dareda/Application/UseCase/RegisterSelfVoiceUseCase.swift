import Dependencies
import DependenciesMacros
import Foundation
import Logging

/// 例文を読んだ録音から本人の声のベクトルを生成して保存する。
/// 録音ファイルは判定・保存の成否にかかわらず処理後に削除する。
@DependencyClient
nonisolated struct RegisterSelfVoiceUseCase: Sendable {
    /// 有効発話が足りない・品質が悪い場合は `SelfVoiceRegistrationError` を投げる。
    var execute: @Sendable (_ recording: Recording) async throws -> Void
}

nonisolated extension RegisterSelfVoiceUseCase: DependencyKey {
    static let liveValue: RegisterSelfVoiceUseCase = {
        let impl = RegisterSelfVoiceUseCaseImpl()
        return RegisterSelfVoiceUseCase(
            execute: impl.execute(_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var registerSelfVoiceUseCase: RegisterSelfVoiceUseCase {
        get { self[RegisterSelfVoiceUseCase.self] }
        set { self[RegisterSelfVoiceUseCase.self] = newValue }
    }
}

nonisolated enum SelfVoiceRegistrationError: Error, Sendable, Equatable {
    /// 有効な発話が基準 (暫定 30 秒) に満たない。
    case insufficientSpeech(TimeInterval)
    /// 音量不足・音割れがある。
    case poorQuality(Set<SpeechQualityIssue>)
}

extension RegisterSelfVoiceUseCase {
    /// 登録に必要な有効発話時間 (秒)。
    nonisolated static let requiredSpeechDuration = ProvisionalParameters.selfVoiceRequiredSpeechDuration
}

private nonisolated struct RegisterSelfVoiceUseCaseImpl: Sendable {
    private static let logger = Logger(label: "Dareda.RegisterSelfVoiceUseCase")

    @Dependency(\.audioFileGateway) private var audioFileGateway
    @Dependency(\.speechQualityService) private var speechQualityService
    @Dependency(\.speakerEmbeddingService) private var speakerEmbeddingService
    @Dependency(\.selfVoiceRepository) private var selfVoiceRepository
    @Dependency(\.date) private var date
    @Dependency(\.metricsGateway) private var metricsGateway

    func execute(_ recording: Recording) async throws {
        Self.logger.info("Self voice registration started")
        do {
            try await register(recording)
        } catch {
            if error is SelfVoiceRegistrationError {
                Self.logger.notice("Self voice registration rejected", metadata: ["error_type": "\(type(of: error))"])
            } else if error is CancellationError || Task.isCancelled {
                Self.logger.debug("Self voice registration cancelled")
            } else {
                Self.logger.error("Self voice registration failed", metadata: ["error_type": "\(type(of: error))"])
            }
            do {
                try await audioFileGateway.delete(recording.fileURL)
            } catch {
                Self.logger.warning("Failed to delete rejected enrollment recording", metadata: ["error_type": "\(type(of: error))"])
            }
            throw error
        }
        do {
            try await audioFileGateway.delete(recording.fileURL)
        } catch {
            Self.logger.warning("Failed to delete enrollment recording", metadata: ["error_type": "\(type(of: error))"])
            throw error
        }
        Self.logger.info("Self voice registration completed")
    }

    private func register(_ recording: Recording) async throws {
        let audio = try await audioFileGateway.samples(recording.fileURL)
        let quality = speechQualityService.analyze(audio, .default)
        metricsGateway.recordValue("metrics.selfVoice.effectiveSpeechDuration", quality.effectiveSpeechDuration)
        metricsGateway.recordValue("metrics.selfVoice.tooQuiet", quality.issues.contains(.tooQuiet) ? 1 : 0)
        metricsGateway.recordValue("metrics.selfVoice.clipping", quality.issues.contains(.clipping) ? 1 : 0)
        guard quality.isAcceptable else {
            Self.logger.notice("Enrollment recording quality is insufficient")
            throw SelfVoiceRegistrationError.poorQuality(quality.issues)
        }
        guard quality.effectiveSpeechDuration >= RegisterSelfVoiceUseCase.requiredSpeechDuration else {
            Self.logger.notice("Enrollment speech duration is insufficient")
            throw SelfVoiceRegistrationError.insufficientSpeech(quality.effectiveSpeechDuration)
        }
        // 録音は 16kHz・モノラルで行っているため、そのまま話者埋め込みの入力にする
        let embedding = try await speakerEmbeddingService.embedding([VoiceSegment(samples: audio.samples)])
        try await selfVoiceRepository.set(SelfVoice(vector: embedding.values, createdAt: date.now))
    }
}

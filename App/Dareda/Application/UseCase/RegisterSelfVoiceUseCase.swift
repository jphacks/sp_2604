import Dependencies
import DependenciesMacros
import Foundation
import Logging

/// 例文を読んだ録音、またはユーザーが選んだ音声ファイルから本人の声のベクトルを生成して保存する。
/// 録音ファイルは判定・保存の成否にかかわらず処理後に削除する。選んだ音声ファイルは削除しない。
@DependencyClient
nonisolated struct RegisterSelfVoiceUseCase: Sendable {
    var execute: @Sendable (_ source: SelfVoiceSource) async throws -> Void
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

/// 本人の声の登録に使う音声。
nonisolated enum SelfVoiceSource: Sendable, Equatable {
    /// アプリで録音した音声。
    case recording(Recording)
    /// ファイルから選んだ音声。
    case file(URL)
}

private nonisolated struct RegisterSelfVoiceUseCaseImpl: Sendable {
    private static let logger = Logger(label: "Dareda.RegisterSelfVoiceUseCase")

    @Dependency(\.audioFileGateway) private var audioFileGateway
    @Dependency(\.speakerEmbeddingService) private var speakerEmbeddingService
    @Dependency(\.selfVoiceRepository) private var selfVoiceRepository
    @Dependency(\.date) private var date

    func execute(_ source: SelfVoiceSource) async throws {
        Self.logger.info("Self voice registration started")
        switch source {
        case let .recording(recording):
            try await executeRecording(recording)
        case let .file(url):
            do {
                try await register(url)
            } catch {
                log(error)
                throw error
            }
        }
        Self.logger.info("Self voice registration completed")
    }

    private func executeRecording(_ recording: Recording) async throws {
        do {
            try await register(recording.fileURL)
        } catch {
            log(error)
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
    }

    private func log(_ error: any Error) {
        if error is CancellationError || Task.isCancelled {
            Self.logger.debug("Self voice registration cancelled")
        } else {
            Self.logger.error("Self voice registration failed", metadata: ["error_type": "\(type(of: error))"])
        }
    }

    private func register(_ url: URL) async throws {
        let audio = try await audioFileGateway.samples(url)
        // 選んだファイルはサンプリングレートが異なりうるため、話者埋め込みの入力形式 (16kHz) に揃える
        let duration = TimeInterval(audio.samples.count) / audio.sampleRate
        let embedding = try await speakerEmbeddingService.embedding([audio.voiceSegment(from: 0, to: duration)])
        try await selfVoiceRepository.set(SelfVoice(vector: embedding.values, createdAt: date.now))
    }
}

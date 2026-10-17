import Dependencies
import DependenciesMacros
import FluidAudio
import Foundation

@DependencyClient
nonisolated struct FluidAudioClient: Sendable {
    var diarize: @Sendable (_ audioURL: URL) async throws -> DiarizationResult
}

nonisolated extension FluidAudioClient: DependencyKey {
    static let liveValue: FluidAudioClient = {
        let impl = FluidAudioClientImpl()
        return FluidAudioClient(
            diarize: impl.diarize(audioURL:)
        )
    }()

    static let testValue = FluidAudioClient.inMemory()
    static let previewValue = FluidAudioClient.inMemory()
}

nonisolated extension FluidAudioClient {
    /// 固定の結果を返すテストダブル。
    static func inMemory(result: DiarizationResult = DiarizationResult(segments: [])) -> FluidAudioClient {
        FluidAudioClient(diarize: { _ in result })
    }

    /// 失敗するテストダブル。
    static func failing() -> FluidAudioClient {
        FluidAudioClient(diarize: { _ in throw CocoaError(.fileReadUnknown) })
    }
}

nonisolated extension DependencyValues {
    var fluidAudioClient: FluidAudioClient {
        get { self[FluidAudioClient.self] }
        set { self[FluidAudioClient.self] = newValue }
    }
}

private nonisolated struct FluidAudioClientImpl: Sendable {
    func diarize(audioURL: URL) async throws -> DiarizationResult {
        let manager = OfflineDiarizerManager()
        try await manager.prepareModels()
        let samples = try AudioConverter().resampleAudioFile(audioURL)
        return try await manager.process(audio: samples)
    }
}

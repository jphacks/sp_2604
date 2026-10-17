import Dependencies
import DependenciesMacros
import FluidAudio
import Foundation
import Synchronization

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

    /// 本人 (0〜15 秒) と相手 (15〜35 秒) の 2 人に分ける結果を返すテストダブル。
    /// 最初の `failureCount` 回は失敗する。
    static func conversation(failureCount: Int = 0) -> FluidAudioClient {
        let callCount = Mutex(0)
        let result = DiarizationResult(segments: [
            TimedSpeakerSegment(speakerId: "S1", embedding: [], startTimeSeconds: 0, endTimeSeconds: 15, qualityScore: 1),
            TimedSpeakerSegment(speakerId: "S2", embedding: [], startTimeSeconds: 15, endTimeSeconds: 35, qualityScore: 1),
        ])
        return FluidAudioClient(diarize: { _ in
            let count = callCount.withLock { value in
                value += 1
                return value
            }
            if count <= failureCount { throw CocoaError(.fileReadUnknown) }
            return result
        })
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

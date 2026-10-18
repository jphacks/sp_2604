import CoreML
import Dependencies
import DependenciesMacros
import FluidAudio
import Foundation
import Synchronization

@DependencyClient
nonisolated struct FluidAudioClient: Sendable {
    /// `minSpeakers` / `maxSpeakers` は推定する話者数の下限・上限 (`nil` なら自動推定)。
    var diarize: @Sendable (_ audioURL: URL, _ minSpeakers: Int?, _ maxSpeakers: Int?) async throws -> DiarizationResult
}

nonisolated extension FluidAudioClient: DependencyKey {
    static let liveValue: FluidAudioClient = {
        let impl = FluidAudioClientImpl()
        return FluidAudioClient(
            diarize: impl.diarize(audioURL:minSpeakers:maxSpeakers:)
        )
    }()

    static let testValue = FluidAudioClient.inMemory()
    static let previewValue = FluidAudioClient.inMemory()
}

nonisolated extension FluidAudioClient {
    /// 固定の結果を返すテストダブル。
    static func inMemory(result: DiarizationResult = DiarizationResult(segments: [])) -> FluidAudioClient {
        FluidAudioClient(diarize: { _, _, _ in result })
    }

    /// 2 人の話者 (0〜15 秒と 15〜30 秒) に分けるテストダブル。`delay` だけ待ってから返す。
    /// 最初の `failureCount` 回は失敗する。
    static func twoSpeakers(delay: Duration = .zero, failureCount: Int = 0) -> FluidAudioClient {
        let callCount = Mutex(0)
        let result = DiarizationResult(segments: [
            TimedSpeakerSegment(speakerId: "S1", embedding: [], startTimeSeconds: 0, endTimeSeconds: 15, qualityScore: 1),
            TimedSpeakerSegment(speakerId: "S2", embedding: [], startTimeSeconds: 15, endTimeSeconds: 30, qualityScore: 1),
        ])
        return FluidAudioClient(diarize: { _, _, _ in
            try await Task.sleep(for: delay)
            let count = callCount.withLock { value in
                value += 1
                return value
            }
            if count <= failureCount { throw CocoaError(.fileReadUnknown) }
            return result
        })
    }

    /// 話者を 1 人だけ分離するテストダブル。
    static func oneSpeaker() -> FluidAudioClient {
        let result = DiarizationResult(segments: [
            TimedSpeakerSegment(speakerId: "S1", embedding: [], startTimeSeconds: 0, endTimeSeconds: 30, qualityScore: 1),
        ])
        return FluidAudioClient(diarize: { _, _, _ in result })
    }

    /// 失敗するテストダブル。
    static func failing() -> FluidAudioClient {
        FluidAudioClient(diarize: { _, _, _ in throw CocoaError(.fileReadUnknown) })
    }
}

nonisolated extension DependencyValues {
    var fluidAudioClient: FluidAudioClient {
        get { self[FluidAudioClient.self] }
        set { self[FluidAudioClient.self] = newValue }
    }
}

private nonisolated struct FluidAudioClientImpl: Sendable {
    func diarize(audioURL: URL, minSpeakers: Int?, maxSpeakers: Int?) async throws -> DiarizationResult {
        var config = OfflineDiarizerConfig.default
        config.clustering.minSpeakers = minSpeakers
        config.clustering.maxSpeakers = maxSpeakers
        let manager = OfflineDiarizerManager(config: config)
        // バックグラウンドでは GPU に処理を投入できないため、GPU を使わない構成に固定する
        let modelConfiguration = MLModelConfiguration()
        modelConfiguration.computeUnits = .cpuAndNeuralEngine
        try await manager.prepareModels(configuration: modelConfiguration)
        let samples = try AudioConverter().resampleAudioFile(audioURL)
        do {
            return try await manager.process(audio: samples)
        } catch OfflineDiarizationError.noSpeechDetected {
            return DiarizationResult(segments: [])
        }
    }
}

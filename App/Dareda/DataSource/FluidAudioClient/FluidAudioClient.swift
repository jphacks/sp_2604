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

    /// 2 人の話者 (0〜15 秒と 15〜30 秒) に分けるテストダブル。`delay` だけ待ってから返す。
    static func twoSpeakers(delay: Duration = .zero) -> FluidAudioClient {
        let result = DiarizationResult(segments: [
            TimedSpeakerSegment(speakerId: "S1", embedding: [], startTimeSeconds: 0, endTimeSeconds: 15, qualityScore: 1),
            TimedSpeakerSegment(speakerId: "S2", embedding: [], startTimeSeconds: 15, endTimeSeconds: 30, qualityScore: 1),
        ])
        return FluidAudioClient(diarize: { _ in
            try await Task.sleep(for: delay)
            return result
        })
    }

    /// 話者を 1 人だけ分離するテストダブル。
    static func oneSpeaker() -> FluidAudioClient {
        let result = DiarizationResult(segments: [
            TimedSpeakerSegment(speakerId: "S1", embedding: [], startTimeSeconds: 0, endTimeSeconds: 30, qualityScore: 1),
        ])
        return FluidAudioClient(diarize: { _ in result })
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

import Dependencies
import DependenciesMacros
import FluidAudio
import Foundation

@DependencyClient
nonisolated struct SpeakerDiarizationGateway: Sendable {
    var diarize: @Sendable (_ audioURL: URL) async throws -> [SpeakerSegment]
}

nonisolated extension SpeakerDiarizationGateway: DependencyKey {
    static let liveValue: SpeakerDiarizationGateway = {
        let impl = SpeakerDiarizationGatewayImpl()
        return SpeakerDiarizationGateway(
            diarize: impl.diarize(audioURL:)
        )
    }()
}

nonisolated extension DependencyValues {
    var speakerDiarizationGateway: SpeakerDiarizationGateway {
        get { self[SpeakerDiarizationGateway.self] }
        set { self[SpeakerDiarizationGateway.self] = newValue }
    }
}

extension SpeakerDiarizationGateway {
    /// 推定する話者数の下限。
    nonisolated static let minimumSpeakers = ProvisionalParameters.diarizationMinimumSpeakers
    /// 推定する話者数の上限。
    nonisolated static let maximumSpeakers = ProvisionalParameters.diarizationMaximumSpeakers
}

private nonisolated struct SpeakerDiarizationGatewayImpl: Sendable {
    @Dependency(\.fluidAudioClient) private var fluidAudioClient

    func diarize(audioURL: URL) async throws -> [SpeakerSegment] {
        let result = try await fluidAudioClient.diarize(
            audioURL, SpeakerDiarizationGateway.minimumSpeakers, SpeakerDiarizationGateway.maximumSpeakers
        )
        return result.segments
            .map {
                SpeakerSegment(
                    speakerID: $0.speakerId,
                    startTime: TimeInterval($0.startTimeSeconds),
                    endTime: TimeInterval($0.endTimeSeconds)
                )
            }
            .sorted { $0.startTime < $1.startTime }
    }
}

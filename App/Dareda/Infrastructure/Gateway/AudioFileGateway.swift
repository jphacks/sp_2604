import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct AudioFileGateway: Sendable {
    var samples: @Sendable (_ url: URL) async throws -> AudioSamples
}

nonisolated extension AudioFileGateway: DependencyKey {
    static let liveValue: AudioFileGateway = {
        let impl = AudioFileGatewayImpl()
        return AudioFileGateway(
            samples: impl.samples(url:)
        )
    }()
}

nonisolated extension DependencyValues {
    var audioFileGateway: AudioFileGateway {
        get { self[AudioFileGateway.self] }
        set { self[AudioFileGateway.self] = newValue }
    }
}

private nonisolated struct AudioFileGatewayImpl: Sendable {
    @Dependency(\.audioFileClient) private var audioFileClient

    func samples(url: URL) async throws -> AudioSamples {
        let (sampleRate, samples) = try audioFileClient.readSamples(url)
        return AudioSamples(sampleRate: sampleRate, samples: samples)
    }
}

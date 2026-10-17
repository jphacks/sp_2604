import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct AudioFileGateway: Sendable {
    var samples: @Sendable (_ url: URL) async throws -> AudioSamples
    /// 音声ファイルを削除する。既に存在しない場合は何もしない。
    var delete: @Sendable (_ url: URL) async throws -> Void
}

nonisolated extension AudioFileGateway: DependencyKey {
    static let liveValue: AudioFileGateway = {
        let impl = AudioFileGatewayImpl()
        return AudioFileGateway(
            samples: impl.samples(url:),
            delete: impl.delete(url:)
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
    @Dependency(\.fileSystemClient) private var fileSystemClient

    func samples(url: URL) async throws -> AudioSamples {
        let (sampleRate, samples) = try audioFileClient.readSamples(url)
        return AudioSamples(sampleRate: sampleRate, samples: samples)
    }

    func delete(url: URL) async throws {
        guard fileSystemClient.fileExists(url) else { return }
        try fileSystemClient.removeItem(url)
    }
}

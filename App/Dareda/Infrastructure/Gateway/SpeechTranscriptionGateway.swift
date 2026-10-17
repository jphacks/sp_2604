import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct SpeechTranscriptionGateway: Sendable {
    /// 音声ファイルを文字起こしし、タイムスタンプ付きの区間を発話順に返す。
    var transcribe: @Sendable (_ audioURL: URL, _ locale: Locale) async throws -> [SpeechSegment]
}

nonisolated extension SpeechTranscriptionGateway: DependencyKey {
    static let liveValue: SpeechTranscriptionGateway = {
        let impl = SpeechTranscriptionGatewayImpl()
        return SpeechTranscriptionGateway(
            transcribe: impl.transcribe(audioURL:locale:)
        )
    }()
}

nonisolated extension DependencyValues {
    var speechTranscriptionGateway: SpeechTranscriptionGateway {
        get { self[SpeechTranscriptionGateway.self] }
        set { self[SpeechTranscriptionGateway.self] = newValue }
    }
}

private nonisolated struct SpeechTranscriptionGatewayImpl: Sendable {
    @Dependency(\.speechClient) private var speechClient

    func transcribe(audioURL: URL, locale: Locale) async throws -> [SpeechSegment] {
        try await speechClient.transcribe(audioURL, locale)
            .map { SpeechSegment(text: $0.text, startTime: $0.start, endTime: $0.end) }
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.startTime < $1.startTime }
    }
}

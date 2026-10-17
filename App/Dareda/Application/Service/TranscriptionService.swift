import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct TranscriptionService: Sendable {
    /// 日本語の録音をオンデバイスで文字起こしし、タイムスタンプ付きの区間を返す。
    /// 同じ録音に対して繰り返し呼ばない (結果の再利用は呼び出し側で行う)。
    var transcribe: @Sendable (_ audioURL: URL) async throws -> [SpeechSegment]
}

nonisolated extension TranscriptionService: DependencyKey {
    static let liveValue: TranscriptionService = {
        let impl = TranscriptionServiceImpl()
        return TranscriptionService(
            transcribe: impl.transcribe(audioURL:)
        )
    }()
}

nonisolated extension DependencyValues {
    var transcriptionService: TranscriptionService {
        get { self[TranscriptionService.self] }
        set { self[TranscriptionService.self] = newValue }
    }
}

private nonisolated struct TranscriptionServiceImpl: Sendable {
    @Dependency(\.speechTranscriptionGateway) private var speechTranscriptionGateway

    func transcribe(audioURL: URL) async throws -> [SpeechSegment] {
        try await speechTranscriptionGateway.transcribe(audioURL, Locale(identifier: "ja_JP"))
    }
}

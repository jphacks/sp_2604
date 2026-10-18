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
            .map { SpeechSegment(text: $0.text, startTime: $0.start, endTime: $0.end, words: Self.words(from: $0.runs)) }
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.startTime < $1.startTime }
    }

    /// 時刻の付いた断片を単語にする。時刻の付かなかった断片 (句読点など) は直前の単語に、
    /// 先頭にある場合は次の単語につなげ、単語をつなげると区間のテキストに戻るようにする。
    /// 時刻の付いた断片が 1 つもなければ空を返す。
    private static func words(from runs: [SpeechClient.Run]) -> [SpeechWord] {
        var words: [SpeechWord] = []
        var leading = ""
        for run in runs {
            if let start = run.start, let end = run.end {
                words.append(SpeechWord(text: leading + run.text, startTime: start, endTime: end))
                leading = ""
            } else if words.isEmpty {
                leading += run.text
            } else {
                words[words.count - 1].text += run.text
            }
        }
        return words
    }
}

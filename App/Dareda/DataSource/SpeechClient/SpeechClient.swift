import AVFoundation
import Dependencies
import DependenciesMacros
import Speech

@DependencyClient
nonisolated struct SpeechClient: Sendable {
    /// 認識結果の 1 区間。`runs` は区間のテキストを分割したもので、つなげると `text` になる。
    typealias Segment = (text: String, start: TimeInterval, end: TimeInterval, runs: [Run])
    /// 区間内のテキストの断片 (おおむね単語)。時刻が付かなかった断片は `start` / `end` が `nil`。
    typealias Run = (text: String, start: TimeInterval?, end: TimeInterval?)

    /// 音声ファイルをオンデバイスで文字起こしし、区間ごとのテキストと時刻を返す。
    var transcribe: @Sendable (_ audioURL: URL, _ locale: Locale) async throws -> [Segment]
}

nonisolated extension SpeechClient: DependencyKey {
    static let liveValue: SpeechClient = {
        let impl = SpeechClientImpl()
        return SpeechClient(
            transcribe: impl.transcribe(audioURL:locale:)
        )
    }()

    static let testValue = SpeechClient.inMemory()
    static let previewValue = SpeechClient.inMemory()
}

nonisolated extension DependencyValues {
    var speechClient: SpeechClient {
        get { self[SpeechClient.self] }
        set { self[SpeechClient.self] = newValue }
    }
}

private nonisolated struct SpeechClientImpl: Sendable {
    enum Failure: Error {
        case unsupportedLocale
    }

    func transcribe(
        audioURL: URL,
        locale: Locale
    ) async throws -> [SpeechClient.Segment] {
        guard await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil else {
            throw Failure.unsupportedLocale
        }
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        // 結果の購読は解析と並行して始める必要がある。
        let collecting = Task {
            var segments: [SpeechClient.Segment] = []
            for try await result in transcriber.results {
                let runs = result.text.runs.map { run -> SpeechClient.Run in
                    (
                        text: String(result.text[run.range].characters),
                        start: run.audioTimeRange?.start.seconds,
                        end: run.audioTimeRange?.end.seconds
                    )
                }
                segments.append((
                    text: String(result.text.characters),
                    start: result.range.start.seconds,
                    end: result.range.end.seconds,
                    runs: runs
                ))
            }
            return segments
        }

        do {
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            let file = try AVAudioFile(forReading: audioURL)
            if let lastSample = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: lastSample)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            return try await collecting.value
        } catch {
            collecting.cancel()
            throw error
        }
    }
}

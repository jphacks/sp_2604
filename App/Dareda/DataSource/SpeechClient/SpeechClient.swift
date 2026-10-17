import AVFoundation
import Dependencies
import DependenciesMacros
import Speech

@DependencyClient
nonisolated struct SpeechClient: Sendable {
    /// 音声ファイルをオンデバイスで文字起こしし、区間ごとの (テキスト, 開始秒, 終了秒) を返す。
    var transcribe: @Sendable (_ audioURL: URL, _ locale: Locale) async throws -> [(text: String, start: TimeInterval, end: TimeInterval)]
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
    ) async throws -> [(text: String, start: TimeInterval, end: TimeInterval)] {
        guard await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil else {
            throw Failure.unsupportedLocale
        }
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        // 結果の購読は解析と並行して始める必要がある。
        let collecting = Task {
            var segments: [(text: String, start: TimeInterval, end: TimeInterval)] = []
            for try await result in transcriber.results {
                segments.append((
                    text: String(result.text.characters),
                    start: result.range.start.seconds,
                    end: result.range.end.seconds
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

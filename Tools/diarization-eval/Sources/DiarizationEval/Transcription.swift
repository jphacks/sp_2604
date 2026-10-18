import AVFoundation
import Foundation
import Speech

/// 文字起こしの 1 区間 (SpeechTranscriber の結果 1 件)。
struct TranscribedSpeech {
    var text: String
    var start: Double
    var end: Double
    /// 単語 (認識結果の run) ごとの時刻。時刻が付かなかった run は含まない。
    var words: [TranscribedWord]
}

struct TranscribedWord {
    var text: String
    var start: Double
    var end: Double
}

/// アプリの `SpeechClient` / `SpeechTranscriptionGateway` と同じ設定 (ja_JP) で文字起こしする。
/// 単語単位の割り当てと比べるため、アプリと違って単語ごとの時刻 (`audioTimeRange`) も取得する。
enum Transcriber {
    static let locale = Locale(identifier: "ja_JP")

    static func transcribe(_ audioURL: URL) async throws -> [TranscribedSpeech] {
        guard await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil else {
            throw TranscriberError.unsupportedLocale
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

        // 結果の購読は解析と並行して始める必要がある
        let collecting = Task {
            var segments: [TranscribedSpeech] = []
            for try await result in transcriber.results {
                let words = result.text.runs.compactMap { run -> TranscribedWord? in
                    guard let range = run.audioTimeRange else { return nil }
                    return TranscribedWord(
                        text: String(result.text[run.range].characters),
                        start: range.start.seconds,
                        end: range.end.seconds
                    )
                }
                segments.append(TranscribedSpeech(
                    text: String(result.text.characters),
                    start: result.range.start.seconds,
                    end: result.range.end.seconds,
                    words: words
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
                .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted { $0.start < $1.start }
        } catch {
            collecting.cancel()
            throw error
        }
    }

    /// 区間と最も長く重なる話者 (アプリの `ConversationAnalysisService.speakerID(overlapping:in:)` と同じ)。
    static func speaker(from start: Double, to end: Double, in segments: [LabeledSegment]) -> String? {
        var overlaps: [String: Double] = [:]
        for segment in segments {
            let overlap = min(end, segment.end) - max(start, segment.start)
            if overlap > 0 { overlaps[segment.speaker, default: 0] += overlap }
        }
        return overlaps.max { $0.value < $1.value }?.key
    }

    /// 区間の中心時刻を含む話者。短い単語は重なりがない (話者分離の区間の隙間に入る) ことがあるため、
    /// 重なりがなければ最も近い区間の話者にする。
    static func nearestSpeaker(from start: Double, to end: Double, in segments: [LabeledSegment]) -> String? {
        if let speaker = speaker(from: start, to: end, in: segments) { return speaker }
        let center = (start + end) / 2
        return segments.min {
            distance(center, $0) < distance(center, $1)
        }?.speaker
    }

    /// 単語単位で話者を割り当て、同じ話者が続く単語をまとめた発言の列。
    static func splitBySpeaker(_ speech: TranscribedSpeech, in segments: [LabeledSegment]) -> [(speaker: String?, words: [TranscribedWord])] {
        var result: [(speaker: String?, words: [TranscribedWord])] = []
        for word in speech.words {
            let speaker = nearestSpeaker(from: word.start, to: word.end, in: segments)
            if let last = result.last, last.speaker == speaker {
                result[result.count - 1].words.append(word)
            } else {
                result.append((speaker, [word]))
            }
        }
        return result
    }

    private static func distance(_ time: Double, _ segment: LabeledSegment) -> Double {
        if time < segment.start { return segment.start - time }
        if time > segment.end { return time - segment.end }
        return 0
    }
}

enum TranscriberError: Error, CustomStringConvertible {
    case unsupportedLocale

    var description: String {
        switch self {
        case .unsupportedLocale: "この Mac では日本語の文字起こし (SpeechTranscriber) を使えません"
        }
    }
}

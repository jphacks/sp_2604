import FluidAudio
import Foundation

let audioExtensions: Set<String> = ["m4a", "wav", "caf", "aac", "mp3", "aiff"]

func log(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func percent(_ value: Double) -> String { String(format: "%.1f%%", value * 100) }

/// 1 つの録音を 1 つの設定で評価した結果。
struct FileResult {
    var speakerCount: Int
    var referenceSpeakerCount: Int?
    var der: DERResult?
    var identification: SelfIdentificationResult?
    /// 本人の判定が正しいか。正解ラベルに self がない、または自動で決まらなかった場合は `nil`。
    var selfCorrect: Bool?
    /// 相手の選択が正しいか。相手が決まらなかった場合は `nil`。
    var partnerCorrect: Bool?
    /// 文字起こしの発言のうち、途中で話者が替わるもの (単語単位で見て 2 人以上にまたがる) の数。
    var switchedSpeechCount: Int?
    var speechCount: Int?
    /// 発言の話者が正解と一致した文字数の割合。アプリと同じ区間単位の割り当てと、単語単位の割り当て。
    var segmentAttributionAccuracy: Double?
    var wordAttributionAccuracy: Double?
}

let options: Options
do {
    options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
} catch OptionsError.help {
    print(Options.usage)
    exit(0)
} catch let OptionsError.invalid(message) {
    log("エラー: \(message)\n\n\(Options.usage)")
    exit(1)
}

let audioFiles = try FileManager.default
    .contentsOfDirectory(at: options.audioDirectory, includingPropertiesForKeys: nil)
    .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
    .filter { $0.standardizedFileURL != options.selfVoiceURL?.standardizedFileURL }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !audioFiles.isEmpty else {
    log("エラー: \(options.audioDirectory.path) に音声ファイルがありません")
    exit(1)
}

let converter = AudioConverter()

// 本人の声のベクトル (アプリの登録と同じく、録音全体から作る)
var embedder: SpeakerEmbedder?
var selfVector: [Float]?
if let selfVoiceURL = options.selfVoiceURL {
    log("ECAPA-TDNN を読み込んでいます: \(options.ecapaURL.path)")
    let loaded = try await SpeakerEmbedder(packageURL: options.ecapaURL)
    guard let vector = try loaded.embedding(converter.resampleAudioFile(selfVoiceURL)) else {
        log("エラー: 本人の声の録音が短すぎます")
        exit(1)
    }
    embedder = loaded
    selfVector = vector
}

log("話者分離モデルを準備しています (初回はダウンロードします)")
try await OfflineDiarizerManager().prepareModels()
let models = try await OfflineDiarizerModels.load()

log("録音を読み込んでいます (\(audioFiles.count) 件)")
var audios: [URL: [Float]] = [:]
var references: [URL: [LabeledSegment]] = [:]
for url in audioFiles {
    audios[url] = try converter.resampleAudioFile(url)
    references[url] = try Labels.reference(for: url)
}

var transcripts: [URL: [TranscribedSpeech]] = [:]
if options.transcribe {
    log("文字起こししています (初回は日本語のモデルをダウンロードします)")
    for url in audioFiles {
        transcripts[url] = try await Transcriber.transcribe(url)
    }
}

var summary: [(setting: DiarizationSetting, results: [FileResult])] = []

for setting in options.settings {
    print("\n== \(setting.label) ==")
    let manager = OfflineDiarizerManager(config: setting.config)
    manager.initialize(models: models)
    var results: [FileResult] = []

    for url in audioFiles {
        let audio = audios[url]!
        let reference = references[url]
        let diarization = try await manager.process(audio: audio)
        let hypothesis = diarization.segments
            .map { LabeledSegment(speaker: $0.speakerId, start: Double($0.startTimeSeconds), end: Double($0.endTimeSeconds)) }
            .sorted { $0.start < $1.start }

        if let outputDirectory = options.outputDirectory {
            let directory = outputDirectory.appendingPathComponent(setting.slug)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileID = url.deletingPathExtension().lastPathComponent
            try Labels.rttm(hypothesis, fileID: fileID)
                .write(to: directory.appendingPathComponent(fileID + ".rttm"), atomically: true, encoding: .utf8)
        }

        var result = FileResult(speakerCount: Set(hypothesis.map(\.speaker)).count)
        var mapping: [String: String] = [:]
        if let reference {
            result.referenceSpeakerCount = Set(reference.map(\.speaker)).count
            result.der = Labels.der(reference: reference, hypothesis: hypothesis, collar: options.collar)
            mapping = Labels.majorityMapping(reference: reference, hypothesis: hypothesis)
        }
        if let embedder, let selfVector {
            let identification = try SelfIdentificationResult.identify(
                segments: hypothesis, audio: audio, selfVector: selfVector,
                threshold: options.selfThreshold, embedder: embedder
            )
            result.identification = identification
            if reference?.contains(where: { $0.speaker == Labels.selfLabel }) == true {
                result.selfCorrect = identification.selfID.map { mapping[$0] == Labels.selfLabel }
                result.partnerCorrect = identification.partnerID.map {
                    mapping[$0].map { $0 != Labels.selfLabel } ?? false
                }
            }
        }
        results.append(result)

        // 録音ごとの詳細
        var header = "\(url.lastPathComponent)  話者 \(result.speakerCount)"
        if let count = result.referenceSpeakerCount { header += " (正解 \(count))" }
        if let der = result.der, der.totalRefSpeech > 0 {
            // 内訳は秒数で返るので、正解の発話時間に対する割合にする
            let total = der.totalRefSpeech
            header += "  DER \(percent(der.der)) (混同 \(percent(der.confusion / total)) / 誤検出 \(percent(der.falseAlarm / total)) / 未検出 \(percent(der.miss / total)))"
        }
        print(header)
        let durations = Dictionary(grouping: hypothesis, by: \.speaker).mapValues { $0.reduce(0) { $0 + $1.duration } }
        let reports = result.identification?.speakers
            ?? durations.keys.sorted().map { SpeakerReport(id: $0, duration: durations[$0]!, selfSimilarity: nil) }
        for speaker in reports {
            var line = String(format: "  %-4@ %6.1fs", speaker.id, speaker.duration)
            if result.identification != nil {
                line += speaker.selfSimilarity.map { String(format: "  本人類似度 %5.2f", $0) } ?? "  本人類似度  (短すぎる)"
            }
            if let truth = mapping[speaker.id] { line += "  → \(truth)" }
            if speaker.id == result.identification?.selfID { line += "  [本人]" }
            if speaker.id == result.identification?.partnerID { line += "  [相手]" }
            print(line)
        }
        if let identification = result.identification {
            var line = "  判定: "
            if identification.selfID == nil {
                line += "本人を自動判定できない (しきい値を超えた話者 \(identification.passedCount) 人 → 手動選択)"
            } else {
                line += "本人 " + (result.selfCorrect.map { $0 ? "✓" : "✗" } ?? "?")
                line += " / 相手 " + (identification.partnerID == nil ? "なし" : result.partnerCorrect.map { $0 ? "✓" : "✗ (本人の声を相手に選んでいる)" } ?? "?")
            }
            print(line)
        }

        if let transcript = transcripts[url] {
            let attribution = attribute(
                transcript, hypothesis: hypothesis, reference: reference, mapping: mapping,
                identification: result.identification
            )
            results[results.count - 1].switchedSpeechCount = attribution.switchedCount
            results[results.count - 1].speechCount = transcript.count
            results[results.count - 1].segmentAttributionAccuracy = attribution.segmentAccuracy
            results[results.count - 1].wordAttributionAccuracy = attribution.wordAccuracy

            if let outputDirectory = options.outputDirectory {
                // 正解ラベルの下書き。話者名を直して録音の隣に置けば、そのまま正解ラベルになる
                let fileID = url.deletingPathExtension().lastPathComponent
                try Labels.audacity(attribution.draft)
                    .write(
                        to: outputDirectory.appendingPathComponent(setting.slug).appendingPathComponent(fileID + ".txt"),
                        atomically: true, encoding: .utf8
                    )
            }
        }
    }
    summary.append((setting, results))
}

// 設定ごとの集計
print("\n== 集計 ==")
for (setting, results) in summary {
    var line = setting.label
    let counted = results.filter { $0.referenceSpeakerCount != nil }
    if !counted.isEmpty {
        let matched = counted.filter { $0.speakerCount == $0.referenceSpeakerCount }.count
        let ders = counted.compactMap { $0.der?.der }
        line += "  話者数一致 \(matched)/\(counted.count)"
        line += "  平均 DER \(percent(ders.reduce(0, +) / Double(ders.count)))"
    } else {
        let counts = results.map(\.speakerCount)
        line += "  話者数 \(counts.map(String.init).joined(separator: ","))"
    }
    let identified = results.compactMap(\.identification)
    if !identified.isEmpty {
        let automatic = identified.filter { $0.selfID != nil }.count
        line += "  本人自動判定 \(automatic)/\(identified.count)"
        let selfJudged = results.compactMap(\.selfCorrect)
        if !selfJudged.isEmpty { line += "  本人正解 \(selfJudged.filter { $0 }.count)/\(selfJudged.count)" }
        let partnerJudged = results.compactMap(\.partnerCorrect)
        if !partnerJudged.isEmpty { line += "  相手正解 \(partnerJudged.filter { $0 }.count)/\(partnerJudged.count)" }
    }
    let switched = results.compactMap(\.switchedSpeechCount).reduce(0, +)
    let speeches = results.compactMap(\.speechCount).reduce(0, +)
    if speeches > 0 { line += "  話者が途中で替わる発言 \(switched)/\(speeches)" }
    let segmentAccuracies = results.compactMap(\.segmentAttributionAccuracy)
    let wordAccuracies = results.compactMap(\.wordAttributionAccuracy)
    if !segmentAccuracies.isEmpty {
        line += "  発言の話者正解率 区間単位 \(percent(segmentAccuracies.reduce(0, +) / Double(segmentAccuracies.count)))"
        line += " / 単語単位 \(percent(wordAccuracies.reduce(0, +) / Double(wordAccuracies.count)))"
    }
    print(line)
}

/// 文字起こしの発言に話者を割り当てて表示し、正解ラベルがあれば割り当ての正解率を求める。
func attribute(
    _ transcript: [TranscribedSpeech],
    hypothesis: [LabeledSegment],
    reference: [LabeledSegment]?,
    mapping: [String: String],
    identification: SelfIdentificationResult?
) -> (switchedCount: Int, segmentAccuracy: Double?, wordAccuracy: Double?, draft: [(start: Double, end: Double, label: String)]) {
    func describe(_ id: String?) -> String {
        guard let id else { return "(話者なし)" }
        if id == identification?.selfID { return "\(id)[本人]" }
        if id == identification?.partnerID { return "\(id)[相手]" }
        return id
    }
    func time(_ start: Double, _ end: Double) -> String { String(format: "%6.1f-%6.1f", start, end) }

    print("  文字起こし (アプリと同じ区間単位の割り当て。途中で話者が替わる発言は └ に単語単位の内訳):")
    var switchedCount = 0
    var draft: [(start: Double, end: Double, label: String)] = []
    var total = 0
    var segmentCorrect = 0
    var wordCorrect = 0
    for speech in transcript {
        let segmentSpeaker = Transcriber.speaker(from: speech.start, to: speech.end, in: hypothesis)
        print("  \(time(speech.start, speech.end))  \(describe(segmentSpeaker))  \(speech.text)")

        let parts = Transcriber.splitBySpeaker(speech, in: hypothesis)
        if parts.count > 1 {
            switchedCount += 1
            for part in parts {
                print("      └ \(time(part.words.first!.start, part.words.last!.end))  \(describe(part.speaker))  \(part.words.map(\.text).joined())")
            }
        }
        if parts.isEmpty {
            draft.append((speech.start, speech.end, "\(segmentSpeaker ?? "unknown") \(speech.text)"))
        } else {
            for part in parts {
                let text = part.words.map(\.text).joined().trimmingCharacters(in: .whitespaces)
                draft.append((part.words.first!.start, part.words.last!.end, "\(part.speaker ?? "unknown") \(text)"))
            }
        }

        guard let reference else { continue }
        let segmentGuess = segmentSpeaker.flatMap { mapping[$0] }
        for word in speech.words {
            guard let truth = Transcriber.nearestSpeaker(from: word.start, to: word.end, in: reference) else { continue }
            let characters = word.text.filter { !$0.isWhitespace }.count
            total += characters
            if segmentGuess == truth { segmentCorrect += characters }
            let wordGuess = Transcriber.nearestSpeaker(from: word.start, to: word.end, in: hypothesis).flatMap { mapping[$0] }
            if wordGuess == truth { wordCorrect += characters }
        }
    }

    print("  話者が途中で替わる発言: \(switchedCount)/\(transcript.count)")
    guard total > 0 else { return (switchedCount, nil, nil, draft) }
    let segmentAccuracy = Double(segmentCorrect) / Double(total)
    let wordAccuracy = Double(wordCorrect) / Double(total)
    print("  発言の話者の正解率 (文字数): 区間単位 \(percent(segmentAccuracy)) / 単語単位 \(percent(wordAccuracy))")
    return (switchedCount, segmentAccuracy, wordAccuracy, draft)
}

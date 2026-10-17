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
    print(line)
}

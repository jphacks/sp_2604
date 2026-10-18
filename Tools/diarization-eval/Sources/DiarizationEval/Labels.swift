import FluidAudio
import Foundation

/// 話者ラベル付きの区間。正解ラベルと分離結果の両方で使う。
struct LabeledSegment {
    var speaker: String
    var start: Double
    var end: Double

    var duration: Double { end - start }
}

enum Labels {
    /// 本人の発話に付ける正解ラベル。
    static let selfLabel = "self"

    /// 録音と同じ名前の .rttm / .txt から正解ラベルを読む。どちらもなければ `nil`。
    static func reference(for audioURL: URL) throws -> [LabeledSegment]? {
        let base = audioURL.deletingPathExtension()
        let rttm = base.appendingPathExtension("rttm")
        if FileManager.default.fileExists(atPath: rttm.path) {
            return try parseRTTM(String(contentsOf: rttm, encoding: .utf8))
        }
        let audacity = base.appendingPathExtension("txt")
        if FileManager.default.fileExists(atPath: audacity.path) {
            return try parseAudacity(String(contentsOf: audacity, encoding: .utf8))
        }
        return nil
    }

    /// `SPEAKER <file> 1 <start> <duration> <NA> <NA> <speaker> <NA> <NA>`
    static func parseRTTM(_ text: String) throws -> [LabeledSegment] {
        try text.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.first == "SPEAKER" else { return nil }
            guard fields.count >= 8, let start = Double(fields[3]), let duration = Double(fields[4]) else {
                throw LabelsError.invalidLine(String(line))
            }
            return LabeledSegment(speaker: String(fields[7]), start: start, end: start + duration)
        }
    }

    /// Audacity のラベル書き出し形式 (`<start>\t<end>\t<label>`)。
    static func parseAudacity(_ text: String) throws -> [LabeledSegment] {
        try text.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            // 周波数範囲の行 (`\t<low>\t<high>`) は読み飛ばす
            if fields.first?.isEmpty == true { return nil }
            guard fields.count >= 3, let start = Double(fields[0]), let end = Double(fields[1]) else {
                throw LabelsError.invalidLine(String(line))
            }
            // ラベルの最初の語を話者名とする (以降は発言などのメモとして無視する)
            guard let speaker = fields[2].split(whereSeparator: \.isWhitespace).first else {
                throw LabelsError.invalidLine(String(line))
            }
            return LabeledSegment(speaker: String(speaker), start: start, end: end)
        }
    }

    /// Audacity のラベル形式。`label` には話者名と、空白区切りでメモを書ける。
    static func audacity(_ labels: [(start: Double, end: Double, label: String)]) -> String {
        labels.map { String(format: "%.3f\t%.3f\t%@", $0.start, $0.end, $0.label) }.joined(separator: "\n") + "\n"
    }

    static func rttm(_ segments: [LabeledSegment], fileID: String) -> String {
        segments.map {
            String(format: "SPEAKER %@ 1 %.3f %.3f <NA> <NA> %@ <NA> <NA>", fileID, $0.start, $0.duration, $0.speaker)
        }
        .joined(separator: "\n") + "\n"
    }

    static func der(reference: [LabeledSegment], hypothesis: [LabeledSegment], collar: Double) -> DERResult {
        DiarizationDER.compute(
            ref: reference.map { DERSpeakerSegment(speaker: $0.speaker, start: $0.start, end: $0.end) },
            hyp: hypothesis.map { DERSpeakerSegment(speaker: $0.speaker, start: $0.start, end: $0.end) },
            collar: collar
        )
    }

    /// 分離結果の各話者を、最も長く重なる正解の話者に対応付ける。
    /// 1 人が複数に分かれた場合も、それぞれが同じ正解の話者に対応する (DER の 1 対 1 対応とは異なる)。
    static func majorityMapping(reference: [LabeledSegment], hypothesis: [LabeledSegment]) -> [String: String] {
        var overlaps: [String: [String: Double]] = [:]
        for hyp in hypothesis {
            for ref in reference {
                let overlap = min(hyp.end, ref.end) - max(hyp.start, ref.start)
                if overlap > 0 { overlaps[hyp.speaker, default: [:]][ref.speaker, default: 0] += overlap }
            }
        }
        return overlaps.compactMapValues { $0.max { $0.value < $1.value }?.key }
    }
}

enum LabelsError: Error, CustomStringConvertible {
    case invalidLine(String)

    var description: String {
        switch self {
        case let .invalidLine(line): "正解ラベルの行を読めません: \(line)"
        }
    }
}

import FluidAudio
import Foundation

/// コマンドライン引数。リストで渡した値はすべての組み合わせ (グリッド) で評価する。
struct Options {
    var audioDirectory: URL
    var thresholds: [Double] = [OfflineDiarizerConfig.Clustering.community.threshold]
    var minSpeakers: [Int?] = [nil]
    var maxSpeakers: [Int?] = [nil]
    var numSpeakers: [Int?] = [nil]
    var minSegmentDurations: [Double] = [OfflineDiarizerConfig.Embedding.community.minSegmentDurationSeconds]
    var selfVoiceURL: URL?
    /// どのディレクトリから実行しても見つかるよう、このソースファイルの位置からリポジトリのルートをたどる
    var ecapaURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // DiarizationEval
        .deletingLastPathComponent() // Sources
        .deletingLastPathComponent() // diarization-eval
        .deletingLastPathComponent() // Tools
        .deletingLastPathComponent()
        .appendingPathComponent("App/Dareda/Resources/ECAPATDNN.mlpackage")
    /// アプリの `ProvisionalParameters.selfIdentificationThreshold` と同じ既定値
    var selfThreshold: Float = 0.5
    var outputDirectory: URL?
    var collar = 0.25
    var transcribe = false

    static let usage = """
        使い方: diarization-eval <録音のディレクトリ> [オプション]

        話者分離の設定 (カンマ区切りで複数指定すると全組み合わせを評価する。none で未指定):
          --threshold <値,...>             クラスタリングのしきい値 (既定 0.6。大きいほど話者がまとまる)
          --min-speakers <数,...>          最小話者数
          --max-speakers <数,...>          最大話者数
          --num-speakers <数,...>          話者数を固定する
          --min-segment-duration <秒,...>  埋め込みに使う区間の最短長 (既定 1.0)

        本人識別 (アプリと同じロジックで本人と相手を判定する):
          --self <音声ファイル>            本人の声の登録用録音
          --ecapa <.mlpackage>             ECAPA-TDNN モデル (既定 App/Dareda/Resources/ECAPATDNN.mlpackage)
          --self-threshold <値>            本人識別のしきい値 (既定 0.5)

        文字起こし (アプリと同じ SpeechTranscriber、ja_JP):
          --transcribe                     発言ごとに話者を割り当てて表示する。アプリと同じ区間単位の割り当てと、単語単位の割り当てを比べる

        その他:
          --out <ディレクトリ>             設定ごとの分離結果を RTTM で書き出す。--transcribe と併用すると正解ラベルの下書きも書き出す
          --collar <秒>                    DER の算出で無視する境界の幅 (既定 0.25)

        正解ラベル: 録音と同じ名前の .rttm または .txt (Audacity のラベル書き出し形式) を置くと DER を算出する。
        本人の発話には self というラベルを付けると、本人・相手の判定が正しいかも確認する。
        """

    static func parse(_ arguments: [String]) throws -> Options {
        var positional: [String] = []
        var flags: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            if argument == "-h" || argument == "--help" { throw OptionsError.help }
            if booleanFlags.contains(argument) {
                flags[argument] = "true"
                index += 1
                continue
            }
            if argument.hasPrefix("--") {
                guard index + 1 < arguments.count else { throw OptionsError.invalid("\(argument) に値がありません") }
                flags[argument] = arguments[index + 1]
                index += 2
            } else {
                positional.append(argument)
                index += 1
            }
        }
        guard positional.count == 1 else { throw OptionsError.invalid("録音のディレクトリを 1 つ指定してください") }

        var options = Options(audioDirectory: URL(fileURLWithPath: positional[0]))
        for (flag, value) in flags {
            switch flag {
            case "--threshold": options.thresholds = try list(value, flag) { Double($0) }
            case "--min-speakers": options.minSpeakers = try optionalList(value, flag)
            case "--max-speakers": options.maxSpeakers = try optionalList(value, flag)
            case "--num-speakers": options.numSpeakers = try optionalList(value, flag)
            case "--min-segment-duration": options.minSegmentDurations = try list(value, flag) { Double($0) }
            case "--self": options.selfVoiceURL = URL(fileURLWithPath: value)
            case "--ecapa": options.ecapaURL = URL(fileURLWithPath: value)
            case "--self-threshold": options.selfThreshold = try single(value, flag) { Float($0) }
            case "--out": options.outputDirectory = URL(fileURLWithPath: value)
            case "--collar": options.collar = try single(value, flag) { Double($0) }
            case "--transcribe": options.transcribe = true
            default: throw OptionsError.invalid("不明なオプション: \(flag)")
            }
        }
        return options
    }

    /// 値を取らないオプション。
    private static let booleanFlags: Set<String> = ["--transcribe"]

    /// 評価するすべての設定の組み合わせ。
    var settings: [DiarizationSetting] {
        var result: [DiarizationSetting] = []
        for threshold in thresholds {
            for minSpeakers in minSpeakers {
                for maxSpeakers in maxSpeakers {
                    for numSpeakers in numSpeakers {
                        for minSegmentDuration in minSegmentDurations {
                            result.append(DiarizationSetting(
                                threshold: threshold,
                                minSpeakers: minSpeakers,
                                maxSpeakers: maxSpeakers,
                                numSpeakers: numSpeakers,
                                minSegmentDuration: minSegmentDuration
                            ))
                        }
                    }
                }
            }
        }
        return result
    }

    private static func list<T>(_ value: String, _ flag: String, _ transform: (String) -> T?) throws -> [T] {
        try value.split(separator: ",").map {
            guard let parsed = transform(String($0)) else { throw OptionsError.invalid("\(flag) の値が不正です: \($0)") }
            return parsed
        }
    }

    private static func optionalList(_ value: String, _ flag: String) throws -> [Int?] {
        try value.split(separator: ",").map {
            if $0 == "none" { return nil }
            guard let parsed = Int($0) else { throw OptionsError.invalid("\(flag) の値が不正です: \($0)") }
            return parsed
        }
    }

    private static func single<T>(_ value: String, _ flag: String, _ transform: (String) -> T?) throws -> T {
        guard let parsed = transform(value) else { throw OptionsError.invalid("\(flag) の値が不正です: \(value)") }
        return parsed
    }
}

enum OptionsError: Error {
    case help
    case invalid(String)
}

/// 話者分離の設定 1 通り。
struct DiarizationSetting {
    var threshold: Double
    var minSpeakers: Int?
    var maxSpeakers: Int?
    var numSpeakers: Int?
    var minSegmentDuration: Double

    var label: String {
        func describe(_ value: Int?) -> String { value.map(String.init) ?? "-" }
        return String(
            format: "th=%.2f min=%@ max=%@ num=%@ seg=%.1f",
            threshold, describe(minSpeakers), describe(maxSpeakers), describe(numSpeakers), minSegmentDuration
        )
    }

    /// ファイル名に使える表記。
    var slug: String {
        label.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "=", with: "")
    }

    var config: OfflineDiarizerConfig {
        var config = OfflineDiarizerConfig(clusteringThreshold: threshold, minSegmentDuration: minSegmentDuration)
        config.clustering.minSpeakers = minSpeakers
        config.clustering.maxSpeakers = maxSpeakers
        config.clustering.numSpeakers = numSpeakers
        return config
    }
}

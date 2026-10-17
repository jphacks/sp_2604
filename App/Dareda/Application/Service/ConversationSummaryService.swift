import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct ConversationSummaryService: Sendable {
    /// 会話を要約する。端末内のコンテキスト量を超えた場合、同意があれば PCC、なければ端末内で分割して要約する。
    /// PCC を使うかがまだ選ばれていなければ `ConversationSummaryError.privateCloudConsentRequired` を投げる。
    var summarize: @Sendable (_ transcript: Transcript) async throws -> ConversationSummary
}

nonisolated extension ConversationSummaryService: DependencyKey {
    static let liveValue: ConversationSummaryService = {
        let impl = ConversationSummaryServiceImpl()
        return ConversationSummaryService(
            summarize: impl.summarize(_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var conversationSummaryService: ConversationSummaryService {
        get { self[ConversationSummaryService.self] }
        set { self[ConversationSummaryService.self] = newValue }
    }
}

private nonisolated struct ConversationSummaryServiceImpl: Sendable {
    @Dependency(\.conversationSummaryGateway) private var conversationSummaryGateway
    @Dependency(\.privateCloudComputeConsentRepository) private var privateCloudComputeConsentRepository

    /// 部分ごとの要約をまとめ直す最大の段数。
    private static let maxMergeRounds = 5

    func summarize(_ transcript: Transcript) async throws -> ConversationSummary {
        guard !transcript.isEmpty else {
            throw ConversationSummaryError.emptyTranscript
        }
        let input = SummaryInput.conversation(transcript)
        if try await conversationSummaryGateway.fits(input, .onDevice) {
            do {
                return try await conversationSummaryGateway.summarize(input, .onDevice)
            } catch ConversationSummaryError.contextSizeExceeded {
                // 見積もりより実際のトークン数が多かった場合は超過として扱う。
            }
        }

        switch privateCloudComputeConsentRepository.get() {
        case .undetermined:
            throw ConversationSummaryError.privateCloudConsentRequired
        case .granted where conversationSummaryGateway.isPrivateCloudAvailable():
            do {
                if try await conversationSummaryGateway.fits(input, .privateCloud) {
                    return try await conversationSummaryGateway.summarize(input, .privateCloud)
                }
            } catch ConversationSummaryError.contextSizeExceeded {
                // PCC のコンテキスト量も超えた場合は端末内で分割する。
            } catch ConversationSummaryError.privateCloudUnavailable {
                // 上限到達や通信障害の場合は端末内で分割する。
            }
        case .granted, .denied:
            break
        }
        return try await summarizeInParts(transcript)
    }

    /// 端末内で会話を分割して部分ごとに要約し、その要約をコンテキスト量に収まるまでまとめ直す。
    private func summarizeInParts(_ transcript: Transcript) async throws -> ConversationSummary {
        let parts = try await split(transcript)
        var summaries: [ConversationSummary] = []
        for (offset, part) in parts.enumerated() {
            let input = SummaryInput.conversationPart(part, index: offset + 1, count: parts.count)
            summaries.append(try await conversationSummaryGateway.summarize(input, .onDevice))
        }

        for _ in 0..<Self.maxMergeRounds {
            let input = SummaryInput.partialSummaries(summaries)
            if try await conversationSummaryGateway.fits(input, .onDevice) {
                return try await conversationSummaryGateway.summarize(input, .onDevice)
            }
            let groups = try await group(summaries)
            // まとめても数が減らない場合は、これ以上縮小できない。
            guard groups.count < summaries.count else {
                throw ConversationSummaryError.cannotReduce
            }
            var merged: [ConversationSummary] = []
            for group in groups {
                merged.append(try await conversationSummaryGateway.summarize(.partialSummaries(group), .onDevice))
            }
            summaries = merged
        }
        throw ConversationSummaryError.cannotReduce
    }

    /// 発話の境界を保ち、各部分がコンテキスト量に収まるように会話を前から順に分割する。
    private func split(_ transcript: Transcript) async throws -> [Transcript] {
        var parts: [Transcript] = []
        var current: [TranscriptSegment] = []
        for segment in transcript.meaningfulSegments {
            for piece in try await pieces(of: segment) {
                let candidate = current + [piece]
                if try await fitsAsPart(candidate) {
                    current = candidate
                } else {
                    parts.append(Transcript(segments: current))
                    current = [piece]
                }
            }
        }
        if !current.isEmpty {
            parts.append(Transcript(segments: current))
        }
        return parts
    }

    /// 1 つでコンテキスト量を超える発話を、話者を保ったまま収まる長さに分ける。
    private func pieces(of segment: TranscriptSegment) async throws -> [TranscriptSegment] {
        if try await fitsAsPart([segment]) {
            return [segment]
        }
        let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 1 else {
            throw ConversationSummaryError.cannotReduce
        }
        let splitIndex = Self.splitIndex(of: text)
        let head = TranscriptSegment(speaker: segment.speaker, text: String(text[..<splitIndex]))
        let tail = TranscriptSegment(speaker: segment.speaker, text: String(text[splitIndex...]))
        return try await pieces(of: head) + pieces(of: tail)
    }

    /// 部分ごとの要約を前から順に、コンテキスト量に収まるまとまりに分ける。
    private func group(_ summaries: [ConversationSummary]) async throws -> [[ConversationSummary]] {
        var groups: [[ConversationSummary]] = []
        var current: [ConversationSummary] = []
        for summary in summaries {
            let candidate = current + [summary]
            if try await conversationSummaryGateway.fits(.partialSummaries(candidate), .onDevice) {
                current = candidate
            } else if current.isEmpty {
                throw ConversationSummaryError.cannotReduce
            } else {
                groups.append(current)
                current = [summary]
            }
        }
        if !current.isEmpty {
            groups.append(current)
        }
        return groups
    }

    private func fitsAsPart(_ segments: [TranscriptSegment]) async throws -> Bool {
        // 部分の番号は分割が終わるまで決まらないため、桁数の多い値で見積もる。
        try await conversationSummaryGateway.fits(
            .conversationPart(Transcript(segments: segments), index: 999, count: 999),
            .onDevice
        )
    }

    /// 中央に最も近い文の区切りの直後で分ける。区切りが無ければ中央で分ける。
    private static func splitIndex(of text: String) -> String.Index {
        let middle = text.index(text.startIndex, offsetBy: text.count / 2)
        let delimiters: Set<Character> = ["。", "！", "？", "!", "?", "\n", "、", ",", " ", "　"]
        let candidates = text.indices
            .filter { delimiters.contains(text[$0]) }
            .map { text.index(after: $0) }
            .filter { $0 > text.startIndex && $0 < text.endIndex }
        return candidates.min {
            abs(text.distance(from: middle, to: $0)) < abs(text.distance(from: middle, to: $1))
        } ?? middle
    }
}

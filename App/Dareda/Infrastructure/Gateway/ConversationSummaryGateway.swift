import Dependencies
import DependenciesMacros
import Foundation
import FoundationModels

nonisolated enum ConversationSummaryError: Error, Equatable {
    case emptyTranscript
    case emptySummary
    /// 入力が言語モデルのコンテキスト量を超えた。
    case contextSizeExceeded
    /// Private Cloud Compute が使えない (利用不可、上限到達、通信・サービス障害)。
    case privateCloudUnavailable
    /// 端末内のコンテキスト量を超えたが、Private Cloud Compute を使うかがまだ選ばれていない。
    case privateCloudConsentRequired
    /// 分割しても入力をコンテキスト量に収められない。
    case cannotReduce
}

@DependencyClient
nonisolated struct ConversationSummaryGateway: Sendable {
    /// Private Cloud Compute を今使えるかを返す。
    var isPrivateCloudAvailable: @Sendable () -> Bool = { false }
    /// 入力と出力の余裕がモデルのコンテキスト量に収まるかを返す。
    var fits: @Sendable (_ input: SummaryInput, _ model: SummarizationModel) async throws -> Bool
    var summarize: @Sendable (_ input: SummaryInput, _ model: SummarizationModel) async throws -> ConversationSummary
}

nonisolated extension ConversationSummaryGateway: DependencyKey {
    static let liveValue: ConversationSummaryGateway = {
        let impl = ConversationSummaryGatewayImpl()
        return ConversationSummaryGateway(
            isPrivateCloudAvailable: impl.isPrivateCloudAvailable,
            fits: impl.fits(_:model:),
            summarize: impl.summarize(_:model:)
        )
    }()
}

nonisolated extension DependencyValues {
    var conversationSummaryGateway: ConversationSummaryGateway {
        get { self[ConversationSummaryGateway.self] }
        set { self[ConversationSummaryGateway.self] = newValue }
    }
}

private nonisolated struct ConversationSummaryGatewayImpl: Sendable {
    @Dependency(\.foundationModelsClient) private var foundationModelsClient

    /// 要約の出力に確保するトークン数。
    private static let reservedOutputTokenCount = 1024

    private static let conversationInstructions = """
        あなたは 1 対 1 の会話を要約するアシスタントです。
        入力は「自分: 発話」「相手: 発話」の形式で 1 行ずつ並んだ会話の文字起こしです。
        次のルールに従い、日本語で簡潔に要約してください。
        - 会話で話された話題、相手について分かったこと、約束や次にやることを含める。
        - 文字起こしに書かれていない内容を推測して付け加えない。
        - 相手の名前や所属を推測・抽出しない。
        - 前置きや見出しは付けず、要約の本文だけを出力する。
        """

    private static let mergeInstructions = """
        あなたは 1 対 1 の会話を要約するアシスタントです。
        入力は、長い会話を前から順に分割し、部分ごとに要約したものです。
        次のルールに従い、日本語で会話全体の要約を 1 つにまとめてください。
        - 会話で話された話題、相手について分かったこと、約束や次にやることを含める。
        - 入力に書かれていない内容を推測して付け加えない。
        - 相手の名前や所属を推測・抽出しない。
        - 前置きや見出しは付けず、要約の本文だけを出力する。
        """

    func isPrivateCloudAvailable() -> Bool {
        foundationModelsClient.privateCloudAvailability() == .available
            && !foundationModelsClient.isPrivateCloudQuotaLimitReached()
    }

    func fits(_ input: SummaryInput, model: SummarizationModel) async throws -> Bool {
        let (instructions, prompt) = Self.request(for: input)
        // PCC のトークン数は数えられないため、端末上のモデルのトークン数で見積もる。
        let tokenCount = try await foundationModelsClient.tokenCount(instructions: instructions, prompt: prompt)
        let contextSize = try await mappingErrors {
            switch model {
            case .onDevice: foundationModelsClient.contextSize()
            case .privateCloud: try await foundationModelsClient.privateCloudContextSize()
            }
        }
        return tokenCount + Self.reservedOutputTokenCount <= contextSize
    }

    func summarize(_ input: SummaryInput, model: SummarizationModel) async throws -> ConversationSummary {
        if case let .conversation(transcript) = input, transcript.isEmpty {
            throw ConversationSummaryError.emptyTranscript
        }
        let (instructions, prompt) = Self.request(for: input)
        let response = try await mappingErrors {
            switch model {
            case .onDevice:
                try await foundationModelsClient.respond(instructions: instructions, prompt: prompt)
            case .privateCloud:
                try await foundationModelsClient.respondWithPrivateCloud(instructions: instructions, prompt: prompt)
            }
        }
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw ConversationSummaryError.emptySummary
        }
        return ConversationSummary(text: text)
    }

    private static func request(for input: SummaryInput) -> (instructions: String, prompt: String) {
        switch input {
        case let .conversation(transcript):
            (conversationInstructions, "次の会話を要約してください。\n\n\(transcript.labeledText)")
        case let .conversationPart(transcript, index, count):
            (
                conversationInstructions,
                "次は長い会話を \(count) 個に分割したうちの \(index) 番目です。この部分を要約してください。\n\n\(transcript.labeledText)"
            )
        case let .partialSummaries(summaries):
            (
                mergeInstructions,
                "次の部分ごとの要約を、会話全体の要約にまとめてください。\n\n"
                    + summaries.enumerated()
                    .map { "\($0.offset + 1). \($0.element.text)" }
                    .joined(separator: "\n")
            )
        }
    }

    /// 言語モデルのエラーのうち、要約の手順で扱うものを `ConversationSummaryError` に変換する。
    /// 安全性による拒否やキャンセルなどは自動で再送しないため、そのまま投げる。
    private func mappingErrors<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch LanguageModelError.contextSizeExceeded {
            throw ConversationSummaryError.contextSizeExceeded
        } catch is PrivateCloudComputeLanguageModel.Error {
            throw ConversationSummaryError.privateCloudUnavailable
        }
    }
}

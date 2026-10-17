import Dependencies
import DependenciesMacros
import Foundation

nonisolated enum ConversationSummaryError: Error, Equatable {
    case emptyTranscript
    case emptySummary
}

@DependencyClient
nonisolated struct ConversationSummaryGateway: Sendable {
    var summarize: @Sendable (_ transcript: Transcript) async throws -> ConversationSummary
}

nonisolated extension ConversationSummaryGateway: DependencyKey {
    static let liveValue: ConversationSummaryGateway = {
        let impl = ConversationSummaryGatewayImpl()
        return ConversationSummaryGateway(
            summarize: impl.summarize(_:)
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

    private static let instructions = """
        あなたは 1 対 1 の会話を要約するアシスタントです。
        入力は「自分: 発話」「相手: 発話」の形式で 1 行ずつ並んだ会話の文字起こしです。
        次のルールに従い、日本語で簡潔に要約してください。
        - 会話で話された話題、相手について分かったこと、約束や次にやることを含める。
        - 文字起こしに書かれていない内容を推測して付け加えない。
        - 相手の名前や所属を推測・抽出しない。
        - 前置きや見出しは付けず、要約の本文だけを出力する。
        """

    func summarize(_ transcript: Transcript) async throws -> ConversationSummary {
        guard !transcript.isEmpty else {
            throw ConversationSummaryError.emptyTranscript
        }
        let prompt = "次の会話を要約してください。\n\n\(transcript.labeledText)"
        let text = try await foundationModelsClient
            .respond(instructions: Self.instructions, prompt: prompt)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw ConversationSummaryError.emptySummary
        }
        return ConversationSummary(text: text)
    }
}

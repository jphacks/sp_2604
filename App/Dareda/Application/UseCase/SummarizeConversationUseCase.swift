import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct SummarizeConversationUseCase: Sendable {
    var summarize: @Sendable (_ transcript: Transcript) async throws -> ConversationSummary
}

nonisolated extension SummarizeConversationUseCase: DependencyKey {
    static let liveValue: SummarizeConversationUseCase = {
        let impl = SummarizeConversationUseCaseImpl()
        return SummarizeConversationUseCase(
            summarize: impl.summarize(_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var summarizeConversationUseCase: SummarizeConversationUseCase {
        get { self[SummarizeConversationUseCase.self] }
        set { self[SummarizeConversationUseCase.self] = newValue }
    }
}

private nonisolated struct SummarizeConversationUseCaseImpl: Sendable {
    @Dependency(\.conversationSummaryGateway) private var conversationSummaryGateway

    func summarize(_ transcript: Transcript) async throws -> ConversationSummary {
        try await conversationSummaryGateway.summarize(transcript)
    }
}

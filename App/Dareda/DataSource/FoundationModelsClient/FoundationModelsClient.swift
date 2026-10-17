import Dependencies
import DependenciesMacros
import FoundationModels

@DependencyClient
nonisolated struct FoundationModelsClient: Sendable {
    /// 端末上の言語モデルに指示とプロンプトを渡し、生成されたテキストをそのまま返す。
    var respond: @Sendable (_ instructions: String, _ prompt: String) async throws -> String
}

nonisolated extension FoundationModelsClient: DependencyKey {
    static let liveValue: FoundationModelsClient = {
        let impl = FoundationModelsClientImpl()
        return FoundationModelsClient(
            respond: impl.respond(instructions:prompt:)
        )
    }()

    static let testValue = FoundationModelsClient.inMemory()
    static let previewValue = FoundationModelsClient.inMemory()

    /// 固定のテキストを返すテストダブル。
    static func inMemory(response: String = "テスト用の要約です。") -> FoundationModelsClient {
        FoundationModelsClient(
            respond: { _, _ in response }
        )
    }
}

nonisolated extension DependencyValues {
    var foundationModelsClient: FoundationModelsClient {
        get { self[FoundationModelsClient.self] }
        set { self[FoundationModelsClient.self] = newValue }
    }
}

private nonisolated struct FoundationModelsClientImpl: Sendable {
    func respond(instructions: String, prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        return response.content
    }
}

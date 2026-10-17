import Dependencies
import DependenciesMacros
import FoundationModels
import Synchronization

@DependencyClient
nonisolated struct FoundationModelsClient: Sendable {
    /// 端末上の言語モデルの利用可否を返す。
    var availability: @Sendable () -> SystemLanguageModel.Availability = { .unavailable(.deviceNotEligible) }
    /// 端末上の言語モデルに指示とプロンプトを渡し、生成されたテキストをそのまま返す。
    var respond: @Sendable (_ instructions: String, _ prompt: String) async throws -> String
}

nonisolated extension FoundationModelsClient: DependencyKey {
    static let liveValue: FoundationModelsClient = {
        let impl = FoundationModelsClientImpl()
        return FoundationModelsClient(
            availability: impl.availability,
            respond: impl.respond(instructions:prompt:)
        )
    }()

    static let testValue = FoundationModelsClient.inMemory()
    static let previewValue = FoundationModelsClient.inMemory()

    /// 固定のテキストを返すテストダブル。`availability` は呼び出すたびに順に返し、最後の値は繰り返す。
    static func inMemory(
        response: String = "テスト用の要約です。",
        availability: [SystemLanguageModel.Availability] = [.available]
    ) -> FoundationModelsClient {
        let index = Mutex(0)
        return FoundationModelsClient(
            availability: {
                let current = index.withLock { value in
                    defer { value += 1 }
                    return value
                }
                return availability[min(current, availability.count - 1)]
            },
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
    func availability() -> SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    func respond(instructions: String, prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        return response.content
    }
}

import Dependencies
import DependenciesMacros
import FoundationModels
import Synchronization

@DependencyClient
nonisolated struct FoundationModelsClient: Sendable {
    /// 端末上の言語モデルの利用可否を返す。
    var availability: @Sendable () -> SystemLanguageModel.Availability = { .unavailable(.deviceNotEligible) }
    /// 端末上の言語モデルのコンテキスト量 (トークン数) を返す。
    var contextSize: @Sendable () -> Int = { 0 }
    /// 指示とプロンプトのトークン数を端末上の言語モデルで数える。
    var tokenCount: @Sendable (_ instructions: String, _ prompt: String) async throws -> Int
    /// 端末上の言語モデルに指示とプロンプトを渡し、生成されたテキストをそのまま返す。
    var respond: @Sendable (_ instructions: String, _ prompt: String) async throws -> String
    /// Private Cloud Compute の言語モデルの利用可否を返す。
    var privateCloudAvailability: @Sendable () -> PrivateCloudComputeLanguageModel.Availability = { .unavailable(.deviceNotEligible) }
    /// Private Cloud Compute の日次上限に達しているかを返す。
    var isPrivateCloudQuotaLimitReached: @Sendable () -> Bool = { true }
    /// Private Cloud Compute の言語モデルのコンテキスト量 (トークン数) を返す。
    var privateCloudContextSize: @Sendable () async throws -> Int
    /// Private Cloud Compute の言語モデルに指示とプロンプトを渡し、生成されたテキストをそのまま返す。
    var respondWithPrivateCloud: @Sendable (_ instructions: String, _ prompt: String) async throws -> String
}

nonisolated extension FoundationModelsClient: DependencyKey {
    static let liveValue: FoundationModelsClient = {
        let impl = FoundationModelsClientImpl()
        return FoundationModelsClient(
            availability: impl.availability,
            contextSize: impl.contextSize,
            tokenCount: impl.tokenCount(instructions:prompt:),
            respond: impl.respond(instructions:prompt:),
            privateCloudAvailability: impl.privateCloudAvailability,
            isPrivateCloudQuotaLimitReached: impl.isPrivateCloudQuotaLimitReached,
            privateCloudContextSize: impl.privateCloudContextSize,
            respondWithPrivateCloud: impl.respondWithPrivateCloud(instructions:prompt:)
        )
    }()

    static let testValue = FoundationModelsClient.inMemory()
    static let previewValue = FoundationModelsClient.inMemory()

    /// 固定のテキストを返すテストダブル。`availability` は呼び出すたびに順に返し、最後の値は繰り返す。
    /// トークン数は文字数で数え、コンテキスト量を超える入力ではコンテキスト超過のエラーを投げる。
    static func inMemory(
        response: String = "テスト用の要約です。",
        availability: [SystemLanguageModel.Availability] = [.available],
        contextSize: Int = 4096,
        privateCloudAvailability: PrivateCloudComputeLanguageModel.Availability = .unavailable(.deviceNotEligible),
        privateCloudResponse: String = "テスト用のPCCの要約です。",
        privateCloudContextSize: Int = 32768
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
            contextSize: { contextSize },
            tokenCount: { instructions, prompt in instructions.count + prompt.count },
            respond: { instructions, prompt in
                try inMemoryResponse(response, contextSize: contextSize, instructions: instructions, prompt: prompt)
            },
            privateCloudAvailability: { privateCloudAvailability },
            isPrivateCloudQuotaLimitReached: { false },
            privateCloudContextSize: { privateCloudContextSize },
            respondWithPrivateCloud: { instructions, prompt in
                try inMemoryResponse(
                    privateCloudResponse,
                    contextSize: privateCloudContextSize,
                    instructions: instructions,
                    prompt: prompt
                )
            }
        )
    }

    private static func inMemoryResponse(
        _ response: String,
        contextSize: Int,
        instructions: String,
        prompt: String
    ) throws -> String {
        let tokenCount = instructions.count + prompt.count
        guard tokenCount <= contextSize else {
            throw LanguageModelError.contextSizeExceeded(
                .init(contextSize: contextSize, tokenCount: tokenCount, debugDescription: "テスト用のコンテキスト超過")
            )
        }
        return response
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

    func contextSize() -> Int {
        SystemLanguageModel.default.contextSize
    }

    func tokenCount(instructions: String, prompt: String) async throws -> Int {
        let model = SystemLanguageModel.default
        let instructionsCount = try await model.tokenCount(for: Instructions(instructions))
        let promptCount = try await model.tokenCount(for: prompt)
        return instructionsCount + promptCount
    }

    func respond(instructions: String, prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        return response.content
    }

    func privateCloudAvailability() -> PrivateCloudComputeLanguageModel.Availability {
        PrivateCloudComputeLanguageModel().availability
    }

    func isPrivateCloudQuotaLimitReached() -> Bool {
        PrivateCloudComputeLanguageModel().quotaUsage.isLimitReached
    }

    func privateCloudContextSize() async throws -> Int {
        try await PrivateCloudComputeLanguageModel().contextSize
    }

    func respondWithPrivateCloud(instructions: String, prompt: String) async throws -> String {
        let session = LanguageModelSession(model: PrivateCloudComputeLanguageModel(), instructions: instructions)
        let response = try await session.respond(to: prompt)
        return response.content
    }
}

import Dependencies
import DependenciesMacros

/// 本人の声が登録済みかを返す。
@DependencyClient
nonisolated struct FetchSelfVoiceRegisteredUseCase: Sendable {
    var execute: @Sendable () async throws -> Bool
}

nonisolated extension FetchSelfVoiceRegisteredUseCase: DependencyKey {
    static let liveValue: FetchSelfVoiceRegisteredUseCase = {
        let impl = FetchSelfVoiceRegisteredUseCaseImpl()
        return FetchSelfVoiceRegisteredUseCase(execute: impl.execute)
    }()
}

nonisolated extension DependencyValues {
    var fetchSelfVoiceRegisteredUseCase: FetchSelfVoiceRegisteredUseCase {
        get { self[FetchSelfVoiceRegisteredUseCase.self] }
        set { self[FetchSelfVoiceRegisteredUseCase.self] = newValue }
    }
}

private nonisolated struct FetchSelfVoiceRegisteredUseCaseImpl: Sendable {
    @Dependency(\.selfVoiceRepository) private var selfVoiceRepository

    func execute() async throws -> Bool {
        try await selfVoiceRepository.get() != nil
    }
}

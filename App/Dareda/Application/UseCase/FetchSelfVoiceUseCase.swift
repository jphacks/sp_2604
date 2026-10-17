import Dependencies
import DependenciesMacros

/// 登録済みの本人の声を返す。未登録なら `nil`。
@DependencyClient
nonisolated struct FetchSelfVoiceUseCase: Sendable {
    var execute: @Sendable () async throws -> SelfVoice?
}

nonisolated extension FetchSelfVoiceUseCase: DependencyKey {
    static let liveValue: FetchSelfVoiceUseCase = {
        let impl = FetchSelfVoiceUseCaseImpl()
        return FetchSelfVoiceUseCase(execute: impl.execute)
    }()
}

nonisolated extension DependencyValues {
    var fetchSelfVoiceUseCase: FetchSelfVoiceUseCase {
        get { self[FetchSelfVoiceUseCase.self] }
        set { self[FetchSelfVoiceUseCase.self] = newValue }
    }
}

private nonisolated struct FetchSelfVoiceUseCaseImpl: Sendable {
    @Dependency(\.selfVoiceRepository) private var selfVoiceRepository

    func execute() async throws -> SelfVoice? {
        try await selfVoiceRepository.get()
    }
}

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct FetchProfilesUseCase: Sendable {
    /// 保存済みのプロフィールを名前順で返す。
    var execute: @Sendable () async throws -> [Profile]
}

nonisolated extension FetchProfilesUseCase: DependencyKey {
    static let liveValue: FetchProfilesUseCase = {
        let impl = FetchProfilesUseCaseImpl()
        return FetchProfilesUseCase(
            execute: impl.execute
        )
    }()
}

nonisolated extension DependencyValues {
    var fetchProfilesUseCase: FetchProfilesUseCase {
        get { self[FetchProfilesUseCase.self] }
        set { self[FetchProfilesUseCase.self] = newValue }
    }
}

private nonisolated struct FetchProfilesUseCaseImpl: Sendable {
    @Dependency(\.profileRepository) private var profileRepository

    func execute() async throws -> [Profile] {
        try await profileRepository.getAll()
    }
}

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct FetchProfileDetailUseCase: Sendable {
    /// プロフィールと初回の出会い記録を返す。プロフィールが存在しなければ `nil`。
    var execute: @Sendable (_ id: Profile.ID) async throws -> ProfileDetailServiceModel?
}

nonisolated extension FetchProfileDetailUseCase: DependencyKey {
    static let liveValue: FetchProfileDetailUseCase = {
        let impl = FetchProfileDetailUseCaseImpl()
        return FetchProfileDetailUseCase(
            execute: impl.execute(id:)
        )
    }()
}

nonisolated extension DependencyValues {
    var fetchProfileDetailUseCase: FetchProfileDetailUseCase {
        get { self[FetchProfileDetailUseCase.self] }
        set { self[FetchProfileDetailUseCase.self] = newValue }
    }
}

private nonisolated struct FetchProfileDetailUseCaseImpl: Sendable {
    @Dependency(\.profileRepository) private var profileRepository
    @Dependency(\.encounterRepository) private var encounterRepository

    func execute(id: Profile.ID) async throws -> ProfileDetailServiceModel? {
        guard let profile = try await profileRepository.get(id) else { return nil }
        let encounter = try await encounterRepository.get(id)
        return ProfileDetailServiceModel(profile: profile, encounter: encounter)
    }
}

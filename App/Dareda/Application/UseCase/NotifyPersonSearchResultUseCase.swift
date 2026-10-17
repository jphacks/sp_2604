import Dependencies
import DependenciesMacros

/// 人物検索の結果を通知する。候補がある場合のみ、1 位の名前だけを通知する。
///
/// アプリ表示中は配信しても表示されない (UserNotificationClient が抑止する) ため、
/// 呼び出し側は前面・背面を区別せず、検索が完了したら呼べばよい。
@DependencyClient
nonisolated struct NotifyPersonSearchResultUseCase: Sendable {
    var execute: @Sendable (_ result: PersonSearchResult) async throws -> Void
}

nonisolated extension NotifyPersonSearchResultUseCase: DependencyKey {
    static let liveValue: NotifyPersonSearchResultUseCase = {
        let impl = NotifyPersonSearchResultUseCaseImpl()
        return NotifyPersonSearchResultUseCase(execute: impl.execute(_:))
    }()
}

nonisolated extension DependencyValues {
    var notifyPersonSearchResultUseCase: NotifyPersonSearchResultUseCase {
        get { self[NotifyPersonSearchResultUseCase.self] }
        set { self[NotifyPersonSearchResultUseCase.self] = newValue }
    }
}

private nonisolated struct NotifyPersonSearchResultUseCaseImpl: Sendable {
    @Dependency(\.profileRepository) private var profileRepository
    @Dependency(\.userNotificationGateway) private var userNotificationGateway

    func execute(_ result: PersonSearchResult) async throws {
        guard case let .candidates(matches) = result,
              let top = matches.first,
              let profile = try await profileRepository.get(top.profileID) else { return }
        try await userNotificationGateway.notifyPersonSearchCandidate(profile.name)
    }
}

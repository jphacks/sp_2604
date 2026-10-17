import Dependencies
import DependenciesMacros

/// 人物検索の結果を通知するための許可を求める。許可されなくてもアプリ内では検索を続けられる。
@DependencyClient
nonisolated struct RequestNotificationPermissionUseCase: Sendable {
    var execute: @Sendable () async throws -> Bool
}

nonisolated extension RequestNotificationPermissionUseCase: DependencyKey {
    static let liveValue: RequestNotificationPermissionUseCase = {
        let impl = RequestNotificationPermissionUseCaseImpl()
        return RequestNotificationPermissionUseCase(execute: impl.execute)
    }()
}

nonisolated extension DependencyValues {
    var requestNotificationPermissionUseCase: RequestNotificationPermissionUseCase {
        get { self[RequestNotificationPermissionUseCase.self] }
        set { self[RequestNotificationPermissionUseCase.self] = newValue }
    }
}

private nonisolated struct RequestNotificationPermissionUseCaseImpl: Sendable {
    @Dependency(\.userNotificationGateway) private var userNotificationGateway

    func execute() async throws -> Bool {
        try await userNotificationGateway.requestAuthorization()
    }
}

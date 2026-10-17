import Dependencies
import DependenciesMacros

/// 通知の許可状態を、許可を求めずに取得する。
@DependencyClient
nonisolated struct FetchNotificationPermissionUseCase: Sendable {
    var execute: @Sendable () async -> NotificationPermission = { .undetermined }
}

nonisolated extension FetchNotificationPermissionUseCase: DependencyKey {
    static let liveValue: FetchNotificationPermissionUseCase = {
        let impl = FetchNotificationPermissionUseCaseImpl()
        return FetchNotificationPermissionUseCase(execute: impl.execute)
    }()
}

nonisolated extension DependencyValues {
    var fetchNotificationPermissionUseCase: FetchNotificationPermissionUseCase {
        get { self[FetchNotificationPermissionUseCase.self] }
        set { self[FetchNotificationPermissionUseCase.self] = newValue }
    }
}

private nonisolated struct FetchNotificationPermissionUseCaseImpl: Sendable {
    @Dependency(\.userNotificationGateway) private var userNotificationGateway

    func execute() async -> NotificationPermission {
        await userNotificationGateway.permission()
    }
}

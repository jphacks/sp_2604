import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct UserNotificationGateway: Sendable {
    /// 現在の通知の許可状態を返す。
    var permission: @Sendable () async -> NotificationPermission = { .undetermined }
    /// 通知の許可を求め、許可されたかを返す。
    var requestAuthorization: @Sendable () async throws -> Bool
    /// 人物検索の 1 位の候補を通知する。名前以外 (所属・日時・場所・要約) は含めない。
    var notifyPersonSearchCandidate: @Sendable (_ name: String) async throws -> Void
    /// 人物検索の通知がタップされたことを流す。
    var personSearchNotificationTaps: @Sendable () -> AsyncStream<Void> = { AsyncStream { $0.finish() } }
}

nonisolated extension UserNotificationGateway: DependencyKey {
    static let liveValue: UserNotificationGateway = {
        let impl = UserNotificationGatewayImpl()
        return UserNotificationGateway(
            permission: impl.permission,
            requestAuthorization: impl.requestAuthorization,
            notifyPersonSearchCandidate: impl.notifyPersonSearchCandidate(_:),
            personSearchNotificationTaps: impl.personSearchNotificationTaps
        )
    }()
}

nonisolated extension DependencyValues {
    var userNotificationGateway: UserNotificationGateway {
        get { self[UserNotificationGateway.self] }
        set { self[UserNotificationGateway.self] = newValue }
    }
}

private nonisolated struct UserNotificationGatewayImpl: Sendable {
    private static let kindKey = "kind"
    private static let personSearchKind = "personSearch"

    @Dependency(\.userNotificationClient) private var userNotificationClient

    func permission() async -> NotificationPermission {
        switch await userNotificationClient.authorizationStatus() {
        case .notDetermined: .undetermined
        case .authorized: .granted
        case .denied: .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await userNotificationClient.requestAuthorization()
    }

    func notifyPersonSearchCandidate(_ name: String) async throws {
        // 同じ識別子で配信し、前回の検索結果の通知を置き換える
        try await userNotificationClient.add(
            Self.personSearchKind,
            "人物検索が完了しました",
            "候補：\(name)さん",
            [Self.kindKey: Self.personSearchKind]
        )
    }

    func personSearchNotificationTaps() -> AsyncStream<Void> {
        let responses = userNotificationClient.responses()
        return AsyncStream { continuation in
            let task = Task {
                for await userInfo in responses where userInfo[Self.kindKey] == Self.personSearchKind {
                    continuation.yield()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

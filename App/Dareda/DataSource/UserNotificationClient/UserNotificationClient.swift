import Dependencies
import DependenciesMacros
import Foundation
import UserNotifications

@DependencyClient
nonisolated struct UserNotificationClient: Sendable {
    enum AuthorizationStatus: Sendable, Equatable {
        case notDetermined
        case authorized
        case denied
    }

    /// 現在の通知の許可状態を返す。確認ダイアログは出さない。
    var authorizationStatus: @Sendable () async -> AuthorizationStatus = { .notDetermined }
    /// 通知の許可を求め、許可されたかを返す。決定済みなら確認ダイアログは出ずに現在の設定を返す。
    var requestAuthorization: @Sendable () async throws -> Bool
    /// ローカル通知を即時に配信する。`userInfo` はタップ時に `responses` へそのまま渡る。
    var add: @Sendable (
        _ identifier: String,
        _ title: String,
        _ body: String,
        _ userInfo: [String: String]
    ) async throws -> Void
    /// タップされた通知の `userInfo`。購読前 (起動直後) のタップも最新の 1 件を受け取る。
    var responses: @Sendable () -> AsyncStream<[String: String]> = { AsyncStream { $0.finish() } }
}

nonisolated extension UserNotificationClient: DependencyKey {
    static let liveValue: UserNotificationClient = {
        let impl = UserNotificationClientImpl()
        return UserNotificationClient(
            authorizationStatus: impl.authorizationStatus,
            requestAuthorization: impl.requestAuthorization,
            add: impl.add(_:_:_:_:),
            responses: impl.responses
        )
    }()

    static let testValue = UserNotificationClient.inMemory()
    static let previewValue = UserNotificationClient.inMemory()
}

nonisolated extension DependencyValues {
    var userNotificationClient: UserNotificationClient {
        get { self[UserNotificationClient.self] }
        set { self[UserNotificationClient.self] = newValue }
    }
}

private nonisolated struct UserNotificationClientImpl: Sendable {
    /// タップを受け取るための delegate。`UNUserNotificationCenter` は delegate を弱参照するため保持する。
    private let delegate = UserNotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    func authorizationStatus() async -> UserNotificationClient.AuthorizationStatus {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .authorized
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func add(_ identifier: String, _ title: String, _ body: String, _ userInfo: [String: String]) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        try await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        )
    }

    func responses() -> AsyncStream<[String: String]> {
        delegate.responses
    }
}

private nonisolated final class UserNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    let responses: AsyncStream<[String: String]>
    private let continuation: AsyncStream<[String: String]>.Continuation

    override init() {
        (responses, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // アプリ表示中は通知しない。通知センターにも残さない
        center.removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
        return []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        continuation.yield(userInfo.reduce(into: [:]) { result, element in
            if let key = element.key as? String, let value = element.value as? String {
                result[key] = value
            }
        })
    }
}

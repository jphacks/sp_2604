import Foundation

nonisolated extension UserNotificationClient {
    /// 通知を配信しないテストダブル。`tappedUserInfo` を渡すと、`tapDelay` 後にその通知がタップされたことにする。
    static func inMemory(
        isAuthorized: Bool = true,
        tappedUserInfo: [String: String]? = nil,
        tapDelay: Duration = .seconds(1)
    ) -> UserNotificationClient {
        UserNotificationClient(
            requestAuthorization: { isAuthorized },
            add: { _, _, _, _ in },
            responses: {
                AsyncStream { continuation in
                    guard let tappedUserInfo else { return }
                    let task = Task {
                        do {
                            try await Task.sleep(for: tapDelay)
                            continuation.yield(tappedUserInfo)
                        } catch { }
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
        )
    }
}

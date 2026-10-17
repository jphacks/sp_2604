import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct UserDefaultsClient: Sendable {
    var value: @Sendable (_ forKey: String) -> Any?
    var setValue: @Sendable (_ value: Any?, _ forKey: String) -> Void
}

nonisolated extension UserDefaultsClient: DependencyKey {
    static let liveValue: UserDefaultsClient = {
        let impl = UserDefaultsClientImpl()
        return UserDefaultsClient(
            value: impl.value(forKey:),
            setValue: impl.setValue(_:forKey:)
        )
    }()

    static let testValue = UserDefaultsClient.inMemory()
    static let previewValue = UserDefaultsClient.inMemory()

    /// メモリ上の辞書に読み書きするテストダブル。
    static func inMemory() -> UserDefaultsClient {
        let storage = InMemoryStorage()
        return UserDefaultsClient(
            value: storage.value(forKey:),
            setValue: storage.setValue(_:forKey:)
        )
    }
}

/// `Any` は `Sendable` ではないため、ロックで保護して共有する。
private nonisolated final class InMemoryStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any] = [:]

    func value(forKey key: String) -> Any? {
        lock.withLock { values[key] }
    }

    func setValue(_ value: Any?, forKey key: String) {
        lock.withLock { values[key] = value }
    }
}

nonisolated extension DependencyValues {
    var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}

private nonisolated struct UserDefaultsClientImpl: Sendable {
    func value(forKey key: String) -> Any? {
        UserDefaults.standard.object(forKey: key)
    }

    func setValue(_ value: Any?, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

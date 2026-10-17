import Dependencies
import DependenciesMacros
import Synchronization
import UIKit

/// `UIApplication.beginBackgroundTask` によるバックグラウンド実行時間の延長。
/// どこまで継続できるかは OS 次第で、継続可能範囲は #27 の実機検証で確認する。
@DependencyClient
nonisolated struct BackgroundTaskClient: Sendable {
    /// バックグラウンド実行を開始し、終了時に渡す識別子を返す。
    /// OS が実行時間を打ち切るときは `expirationHandler` を呼び、その後このタスクを終了する。
    var begin: @Sendable (
        _ name: String, _ expirationHandler: @escaping @Sendable () -> Void
    ) async -> Int = { _, _ in 0 }
    var end: @Sendable (_ identifier: Int) async -> Void
}

nonisolated extension BackgroundTaskClient: DependencyKey {
    static let liveValue: BackgroundTaskClient = {
        let impl = BackgroundTaskClientImpl()
        return BackgroundTaskClient(
            begin: impl.begin(name:expirationHandler:),
            end: impl.end(identifier:)
        )
    }()

    static let testValue = BackgroundTaskClient.inMemory()
    static let previewValue = BackgroundTaskClient.inMemory()
}

nonisolated extension DependencyValues {
    var backgroundTaskClient: BackgroundTaskClient {
        get { self[BackgroundTaskClient.self] }
        set { self[BackgroundTaskClient.self] = newValue }
    }
}

private nonisolated struct BackgroundTaskClientImpl: Sendable {
    func begin(name: String, expirationHandler: @escaping @Sendable () -> Void) async -> Int {
        await MainActor.run {
            let identifier = Mutex(UIBackgroundTaskIdentifier.invalid)
            let value = UIApplication.shared.beginBackgroundTask(withName: name) {
                expirationHandler()
                // 打ち切り時に終了しないとアプリが強制終了されるため、ここで終了する。
                UIApplication.shared.endBackgroundTask(identifier.withLock { $0 })
            }
            identifier.withLock { $0 = value }
            return value.rawValue
        }
    }

    func end(identifier: Int) async {
        await MainActor.run {
            UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: identifier))
        }
    }
}

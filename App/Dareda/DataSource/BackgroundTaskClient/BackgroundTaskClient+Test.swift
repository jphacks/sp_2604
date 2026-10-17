import Foundation
import Synchronization
import UIKit

nonisolated extension BackgroundTaskClient {
    /// OS を使わないテストダブル。
    /// `expiresOnEnteringBackground` を指定すると、最初にバックグラウンドへ移行したときに
    /// 実行中のタスクを打ち切る (OS による中断の模擬)。
    static func inMemory(expiresOnEnteringBackground: Bool = false) -> BackgroundTaskClient {
        let tasks = InMemoryBackgroundTasks()
        return BackgroundTaskClient(
            begin: { _, expirationHandler in
                let identifier = tasks.add()
                guard expiresOnEnteringBackground else { return identifier }
                let watcher = Task {
                    let notifications = NotificationCenter.default.notifications(
                        named: UIApplication.didEnterBackgroundNotification
                    )
                    for await _ in notifications {
                        if tasks.expireOnce() { expirationHandler() }
                        return
                    }
                }
                tasks.setWatcher(watcher, for: identifier)
                return identifier
            },
            end: { identifier in tasks.remove(identifier) }
        )
    }
}

private nonisolated final class InMemoryBackgroundTasks: Sendable {
    private struct State {
        var nextIdentifier = 1
        var watchers: [Int: Task<Void, Never>] = [:]
        var hasExpired = false
    }

    private let state = Mutex(State())

    func add() -> Int {
        state.withLock { state in
            defer { state.nextIdentifier += 1 }
            return state.nextIdentifier
        }
    }

    func setWatcher(_ watcher: Task<Void, Never>, for identifier: Int) {
        state.withLock { $0.watchers[identifier] = watcher }
    }

    func remove(_ identifier: Int) {
        state.withLock { $0.watchers.removeValue(forKey: identifier) }?.cancel()
    }

    /// 打ち切りは 1 回だけ行う。1 回目なら `true` を返す。
    func expireOnce() -> Bool {
        state.withLock { state in
            guard !state.hasExpired else { return false }
            state.hasExpired = true
            return true
        }
    }
}

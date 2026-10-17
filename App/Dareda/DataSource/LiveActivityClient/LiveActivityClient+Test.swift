import Foundation
import Synchronization

nonisolated extension LiveActivityClient {
    /// ActivityKit を使わないテストダブル。表示中の内容をメモリに保持する。
    static func inMemory() -> LiveActivityClient {
        let current = Mutex<RecordingActivityAttributes.ContentState?>(nil)
        return LiveActivityClient(
            start: { state in current.withLock { $0 = state } },
            update: { state in current.withLock { $0 = state } },
            end: { current.withLock { $0 = nil } }
        )
    }
}

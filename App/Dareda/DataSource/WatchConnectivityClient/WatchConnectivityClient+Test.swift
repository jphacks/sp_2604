import Foundation

nonisolated extension WatchConnectivityClient {
    /// Apple Watch とつながっていない状態。送信は捨て、何も受信しない。
    static func inMemory() -> Self {
        WatchConnectivityClient(
            activate: {},
            updateSnapshot: { _ in },
            receivedFiles: { AsyncStream { $0.finish() } },
            receivedCommands: { AsyncStream { $0.finish() } }
        )
    }
}

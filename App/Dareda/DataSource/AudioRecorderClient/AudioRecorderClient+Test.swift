import Foundation

nonisolated extension AudioRecorderClient {
    /// マイクを使わないテストダブル。権限は許可済みで、録音開始からの経過時間を長さとして返す。
    static func inMemory() -> AudioRecorderClient {
        let startedAt = StartedAtBox()
        return AudioRecorderClient(
            recordPermission: { .granted },
            requestRecordPermission: { true },
            start: {
                startedAt.set(Date())
                return FileManager.default.temporaryDirectory
                    .appending(path: "\(UUID().uuidString).m4a", directoryHint: .notDirectory)
            },
            stop: {
                guard let date = startedAt.take() else { return 0 }
                return Date().timeIntervalSince(date)
            },
            interruptions: { AsyncStream { _ in } }
        )
    }
}

private nonisolated final class StartedAtBox: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date?

    func set(_ date: Date) {
        lock.withLock { self.date = date }
    }

    func take() -> Date? {
        lock.withLock {
            defer { date = nil }
            return date
        }
    }
}

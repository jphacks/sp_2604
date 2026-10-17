import Foundation

nonisolated extension AudioRecorderClient {
    /// マイクを使わないテストダブル。権限の読取順序と要求結果を指定できる。
    /// 録音開始からの経過時間を長さとして返す。
    static func inMemory(
        permissions: [Permission] = [.granted],
        permissionAfterRequest: Bool = true
    ) -> AudioRecorderClient {
        let startedAt = StartedAtBox()
        let permission = PermissionBox(permissions)
        return AudioRecorderClient(
            recordPermission: { permission.next() },
            requestRecordPermission: { permissionAfterRequest },
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

private nonisolated final class PermissionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var permissions: [AudioRecorderClient.Permission]

    init(_ permissions: [AudioRecorderClient.Permission]) {
        self.permissions = permissions.isEmpty ? [.undetermined] : permissions
    }

    func next() -> AudioRecorderClient.Permission {
        lock.withLock {
            if permissions.count > 1 { return permissions.removeFirst() }
            return permissions[0]
        }
    }
}

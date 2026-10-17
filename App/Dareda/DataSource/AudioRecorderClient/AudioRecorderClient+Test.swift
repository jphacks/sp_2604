import Foundation

nonisolated extension AudioRecorderClient {
    /// マイクを使わないテストダブル。権限の読取順序と要求結果を指定できる。
    /// 録音開始からの経過時間を長さとして返す。
    static func inMemory(
        permissions: [Permission] = [.granted],
        permissionAfterRequest: Bool = true,
        elapsedTimes: [TimeInterval] = [],
        interruptionDelay: Duration? = nil,
        failsToStart: Bool = false
    ) -> AudioRecorderClient {
        let startedAt = StartedAtBox()
        let permission = PermissionBox(permissions)
        let times = ElapsedTimeBox(elapsedTimes)
        return AudioRecorderClient(
            recordPermission: { permission.next() },
            requestRecordPermission: { permissionAfterRequest },
            start: {
                if failsToStart { throw CocoaError(.fileWriteUnknown) }
                startedAt.set(Date())
                return FileManager.default.temporaryDirectory
                    .appending(path: "\(UUID().uuidString).m4a", directoryHint: .notDirectory)
            },
            stop: {
                guard let date = startedAt.take() else { return 0 }
                return elapsedTimes.last ?? Date().timeIntervalSince(date)
            },
            elapsedTime: { times.next() ?? startedAt.elapsedTime() },
            interruptions: {
                AsyncStream { continuation in
                    guard let interruptionDelay else { return }
                    let task = Task {
                        do {
                            try await Task.sleep(for: interruptionDelay)
                            continuation.yield()
                        } catch { }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
        )
    }
}

private nonisolated final class StartedAtBox: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date?

    func set(_ date: Date) {
        lock.withLock { self.date = date }
    }

    func elapsedTime() -> TimeInterval {
        lock.withLock { date.map { Date().timeIntervalSince($0) } ?? 0 }
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

private nonisolated final class ElapsedTimeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var times: [TimeInterval]

    init(_ times: [TimeInterval]) { self.times = times }

    func next() -> TimeInterval? {
        lock.withLock {
            if times.count > 1 { return times.removeFirst() }
            return times.first
        }
    }
}

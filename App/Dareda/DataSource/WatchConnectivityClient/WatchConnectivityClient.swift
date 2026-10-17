import Dependencies
import DependenciesMacros
import Foundation
import Logging
import WatchConnectivity

/// ペアリングした Apple Watch との通信。Apple Watch アプリが入っていなければ送信は何もしない。
@DependencyClient
nonisolated struct WatchConnectivityClient: Sendable {
    /// セッションを有効にする。受信を始める前に呼ぶ。
    var activate: @Sendable () -> Void
    /// Apple Watch に最新の状態を送る。届く前に次の状態を送ると、古い状態は破棄される。
    var updateSnapshot: @Sendable (_ snapshot: WatchSnapshot) throws -> Void
    /// Apple Watch で録音したファイル。一時領域に移した URL とメタデータを流す。
    var receivedFiles: @Sendable () -> AsyncStream<ReceivedFile> = { AsyncStream { $0.finish() } }
    var receivedCommands: @Sendable () -> AsyncStream<WatchCommand> = { AsyncStream { $0.finish() } }
}

nonisolated extension WatchConnectivityClient {
    struct ReceivedFile: Sendable, Equatable {
        var url: URL
        var startedAt: Date?
        var isAdditional: Bool
    }
}

nonisolated extension WatchConnectivityClient: DependencyKey {
    static let liveValue: WatchConnectivityClient = {
        let impl = WatchConnectivityClientImpl()
        return WatchConnectivityClient(
            activate: impl.activate,
            updateSnapshot: impl.updateSnapshot(_:),
            receivedFiles: impl.receivedFiles,
            receivedCommands: impl.receivedCommands
        )
    }()

    static let testValue = WatchConnectivityClient.inMemory()
    static let previewValue = WatchConnectivityClient.inMemory()
}

nonisolated extension DependencyValues {
    var watchConnectivityClient: WatchConnectivityClient {
        get { self[WatchConnectivityClient.self] }
        set { self[WatchConnectivityClient.self] = newValue }
    }
}

private nonisolated struct WatchConnectivityClientImpl: Sendable {
    /// `WCSession` は delegate を弱参照するため保持する。
    private let delegate = WatchSessionDelegate()

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.delegate == nil else { return }
        session.delegate = delegate
        session.activate()
    }

    func updateSnapshot(_ snapshot: WatchSnapshot) throws {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let data = try JSONEncoder().encode(snapshot)
        try session.updateApplicationContext([WatchSyncKey.snapshot: data])
    }

    func receivedFiles() -> AsyncStream<WatchConnectivityClient.ReceivedFile> {
        delegate.files.stream()
    }

    func receivedCommands() -> AsyncStream<WatchCommand> {
        delegate.commands.stream()
    }
}

private nonisolated final class WatchSessionDelegate: NSObject, WCSessionDelegate, @unchecked Sendable {
    private static let logger = Logger(label: "Dareda.WatchSessionDelegate")

    let files = Broadcast<WatchConnectivityClient.ReceivedFile>()
    let commands = Broadcast<WatchCommand>()

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error {
            Self.logger.error("Watch session activation failed", metadata: ["error_type": "\(type(of: error))"])
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // 別の Apple Watch に切り替えたときは、新しい Apple Watch との通信のために有効にし直す
        session.activate()
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // 受け取ったファイルはこのメソッドから戻ると削除されるため、先に一時領域へ移す
        let directory = FileManager.default.temporaryDirectory.appending(path: "WatchRecordings", directoryHint: .isDirectory)
        let destination = directory.appending(path: "\(UUID().uuidString).\(file.fileURL.pathExtension)")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: file.fileURL, to: destination)
        } catch {
            Self.logger.error("Watch recording could not be saved", metadata: ["error_type": "\(type(of: error))"])
            return
        }
        let startedAt = (file.metadata?[WatchSyncKey.startedAt] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
        let isAdditional = file.metadata?[WatchSyncKey.isAdditional] as? Bool ?? false
        files.yield(WatchConnectivityClient.ReceivedFile(url: destination, startedAt: startedAt, isAdditional: isAdditional))
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message[WatchSyncKey.command] as? Data,
              let command = try? JSONDecoder().decode(WatchCommand.self, from: data)
        else { return }
        commands.yield(command)
    }
}

/// 購読前に届いた値も失わないよう、購読者がいなければ溜めておき、最初の購読者に渡す。
nonisolated final class Broadcast<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
    private var pending: [Value] = []

    func yield(_ value: Value) {
        let targets = lock.withLock {
            if continuations.isEmpty { pending.append(value) }
            return Array(continuations.values)
        }
        for continuation in targets { continuation.yield(value) }
    }

    func stream() -> AsyncStream<Value> {
        AsyncStream { continuation in
            let id = UUID()
            let pending = lock.withLock {
                continuations[id] = continuation
                defer { self.pending = [] }
                return self.pending
            }
            for value in pending { continuation.yield(value) }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.withLock { _ = self.continuations.removeValue(forKey: id) }
            }
        }
    }
}

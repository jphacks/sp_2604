import Dependencies
import DependenciesMacros
import Foundation

/// Apple Watch アプリとの同期。
@DependencyClient
nonisolated struct WatchSyncGateway: Sendable {
    var activate: @Sendable () -> Void
    var send: @Sendable (_ snapshot: WatchSnapshot) throws -> Void
    /// Apple Watch で録音した音声ファイル。
    var recordings: @Sendable () -> AsyncStream<WatchRecording> = { AsyncStream { $0.finish() } }
    var commands: @Sendable () -> AsyncStream<WatchCommand> = { AsyncStream { $0.finish() } }
}

/// Apple Watch から届いた録音ファイル。
nonisolated struct WatchRecording: Sendable, Equatable {
    var fileURL: URL
    var startedAt: Date?
    var kind: WatchRecordingKind
}

nonisolated extension WatchSyncGateway: DependencyKey {
    static let liveValue: WatchSyncGateway = {
        @Dependency(\.watchConnectivityClient) var client
        return WatchSyncGateway(
            activate: { client.activate() },
            send: { try client.updateSnapshot($0) },
            recordings: {
                let files = client.receivedFiles()
                return AsyncStream { continuation in
                    let task = Task {
                        for await file in files {
                            continuation.yield(WatchRecording(fileURL: file.url, startedAt: file.startedAt, kind: file.kind))
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            commands: { client.receivedCommands() }
        )
    }()
}

nonisolated extension DependencyValues {
    var watchSyncGateway: WatchSyncGateway {
        get { self[WatchSyncGateway.self] }
        set { self[WatchSyncGateway.self] = newValue }
    }
}

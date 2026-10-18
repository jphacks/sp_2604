import Dependencies
import DependenciesMacros
import Foundation
import Synchronization

/// App Intent からアプリの画面への依頼の受け渡し。依頼は文字列の種類で表す。
@DependencyClient
nonisolated struct AppIntentRequestClient: Sendable {
    var send: @Sendable (_ kind: String) -> Void
    /// 依頼を流す。購読者ごとに全ての依頼を受け取る。
    /// 購読者が 1 人もいない間 (起動直後) に届いた依頼は、最初の購読者に渡す。
    var requests: @Sendable () -> AsyncStream<String> = { AsyncStream { $0.finish() } }
}

nonisolated extension AppIntentRequestClient: DependencyKey {
    static let liveValue: AppIntentRequestClient = .inMemory()
    static let testValue: AppIntentRequestClient = .inMemory()
    static let previewValue: AppIntentRequestClient = .inMemory()

    /// App Intent はアプリのプロセス内で実行されるため、本番もメモリ上で受け渡す。
    static func inMemory() -> AppIntentRequestClient {
        let impl = AppIntentRequestClientImpl()
        return AppIntentRequestClient(
            send: impl.send(_:),
            requests: impl.requests
        )
    }
}

nonisolated extension DependencyValues {
    var appIntentRequestClient: AppIntentRequestClient {
        get { self[AppIntentRequestClient.self] }
        set { self[AppIntentRequestClient.self] = newValue }
    }
}

private nonisolated final class AppIntentRequestClientImpl: Sendable {
    private struct State {
        var continuations: [UUID: AsyncStream<String>.Continuation] = [:]
        var pending: [String] = []
    }

    private let state = Mutex(State())

    func send(_ kind: String) {
        state.withLock { state in
            if state.continuations.isEmpty {
                state.pending.append(kind)
            } else {
                for continuation in state.continuations.values {
                    continuation.yield(kind)
                }
            }
        }
    }

    func requests() -> AsyncStream<String> {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        let id = UUID()
        state.withLock { state in
            for kind in state.pending {
                continuation.yield(kind)
            }
            state.pending = []
            state.continuations[id] = continuation
        }
        continuation.onTermination = { [weak self] _ in
            self?.state.withLock { _ = $0.continuations.removeValue(forKey: id) }
        }
        return stream
    }
}

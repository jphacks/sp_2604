import Foundation
import Synchronization

nonisolated extension CallKitClient {
    /// 着信画面を出さないテストダブル。`answerDelay` 後に応答したことにする。`nil` なら応答しない。
    /// `failsToReport` を指定すると、着信の報告に失敗する。
    static func inMemory(answerDelay: Duration? = .milliseconds(300), failsToReport: Bool = false) -> CallKitClient {
        let calls = InMemoryCalls()
        return CallKitClient(
            events: { id in
                AsyncStream { continuation in calls.add(id, continuation) }
            },
            reportIncomingCall: { id, _ in
                if failsToReport {
                    calls.finish(id)
                    throw CocoaError(.featureUnsupported)
                }
                guard let answerDelay else { return }
                Task {
                    guard (try? await Task.sleep(for: answerDelay)) != nil else { return }
                    calls.yield(.answered, to: id)
                    calls.yield(.audioActivated, to: id)
                }
            },
            endCall: { id, _ in calls.finish(id) }
        )
    }
}

private nonisolated final class InMemoryCalls: Sendable {
    private let continuations = Mutex<[UUID: AsyncStream<CallKitClient.Event>.Continuation]>([:])

    func add(_ id: UUID, _ continuation: AsyncStream<CallKitClient.Event>.Continuation) {
        continuations.withLock { $0[id] = continuation }
    }

    func yield(_ event: CallKitClient.Event, to id: UUID) {
        _ = continuations.withLock { $0[id]?.yield(event) }
    }

    func finish(_ id: UUID) {
        guard let continuation = continuations.withLock({ $0.removeValue(forKey: id) }) else { return }
        continuation.yield(.ended)
        continuation.finish()
    }
}

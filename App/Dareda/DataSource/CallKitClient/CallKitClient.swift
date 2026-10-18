import AVFoundation
import CallKit
import Dependencies
import DependenciesMacros
import Foundation
import Synchronization
import UIKit

/// CallKit による着信の表示。アプリ内からローカルで着信を報告する (VoIP プッシュは使わない)。
@DependencyClient
nonisolated struct CallKitClient: Sendable {
    enum Event: Sendable, Equatable {
        /// ユーザーが応答した。
        case answered
        /// 通話用のオーディオセッションが有効になった。ここから音声を再生できる。
        case audioActivated
        /// 拒否・終話などで通話が終わった。これ以降イベントは流れない。
        case ended
    }

    enum EndReason: Sendable, Equatable {
        /// 応答されないまま着信をやめた。
        case unanswered
        /// アプリ側から通話を切った。
        case remoteEnded
    }

    /// `id` の通話のイベント。`reportIncomingCall` より前に購読しておく。
    var events: @Sendable (_ id: UUID) -> AsyncStream<Event> = { _ in AsyncStream { $0.finish() } }
    /// 着信を報告し、着信画面を表示する。着信を出せなければエラーを投げる。
    var reportIncomingCall: @Sendable (_ id: UUID, _ callerName: String) async throws -> Void
    /// 着信または通話を終える。終了済みなら何もしない。
    var endCall: @Sendable (_ id: UUID, _ reason: EndReason) async -> Void
}

nonisolated extension CallKitClient: DependencyKey {
    static let liveValue: CallKitClient = {
        let impl = CallKitClientImpl()
        return CallKitClient(
            events: impl.events(id:),
            reportIncomingCall: impl.reportIncomingCall(id:callerName:),
            endCall: impl.endCall(id:reason:)
        )
    }()

    static let testValue = CallKitClient.inMemory()
    static let previewValue = CallKitClient.inMemory()
}

nonisolated extension DependencyValues {
    var callKitClient: CallKitClient {
        get { self[CallKitClient.self] }
        set { self[CallKitClient.self] = newValue }
    }
}

/// `CXProvider` はスレッドセーフで、可変の状態は `Mutex` の中でだけ扱う。
private nonisolated final class CallKitClientImpl: NSObject, CXProviderDelegate, @unchecked Sendable {
    private struct Call {
        var continuation: AsyncStream<CallKitClient.Event>.Continuation?
        var backgroundTask: UIBackgroundTaskIdentifier?
    }

    private let provider: CXProvider
    private let calls = Mutex<[UUID: Call]>([:])

    override init() {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = false
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        // 相手の前で使うため、電話アプリの履歴に残さない
        configuration.includesCallsInRecents = false
        provider = CXProvider(configuration: configuration)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    func events(id: UUID) -> AsyncStream<CallKitClient.Event> {
        AsyncStream { continuation in
            calls.withLock { $0[id, default: Call()].continuation = continuation }
        }
    }

    func reportIncomingCall(id: UUID, callerName: String) async throws {
        // 着信中にアプリがサスペンドされないよう、通話が終わるまで実行時間を延長する
        let backgroundTask = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: "CallKitClient.incomingCall") { [self] in
                Task { await endCall(id: id, reason: .unanswered) }
            }
        }
        calls.withLock { $0[id, default: Call()].backgroundTask = backgroundTask }

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        update.localizedCallerName = callerName
        update.hasVideo = false
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        do {
            try await provider.reportNewIncomingCall(with: id, update: update)
        } catch {
            await finish(id)
            throw error
        }
    }

    func endCall(id: UUID, reason: CallKitClient.EndReason) async {
        guard calls.withLock({ $0[id] }) != nil else { return }
        let reason: CXCallEndedReason =
            switch reason {
            case .unanswered: .unanswered
            case .remoteEnded: .remoteEnded
            }
        provider.reportCall(with: id, endedAt: nil, reason: reason)
        await finish(id)
    }

    /// 通話を終了済みにし、イベントの購読を終え、延長した実行時間を返す。
    private func finish(_ id: UUID) async {
        guard let call = calls.withLock({ $0.removeValue(forKey: id) }) else { return }
        call.continuation?.yield(.ended)
        call.continuation?.finish()
        if let backgroundTask = call.backgroundTask {
            await MainActor.run { UIApplication.shared.endBackgroundTask(backgroundTask) }
        }
    }

    private func yield(_ event: CallKitClient.Event, to id: UUID) {
        _ = calls.withLock { $0[id]?.continuation?.yield(event) }
    }

    // MARK: - CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        let ids = calls.withLock { Array($0.keys) }
        Task {
            for id in ids { await finish(id) }
        }
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // 通話と同じく受話口から再生するため、オーディオセッションを通話用に設定する。
        // 有効化は CallKit が行い、完了すると provider(_:didActivate:) が呼ばれる
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat)
        yield(.answered, to: action.callUUID)
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let id = action.callUUID
        action.fulfill()
        Task { await finish(id) }
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        let ids = calls.withLock { Array($0.keys) }
        for id in ids { yield(.audioActivated, to: id) }
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {}
}

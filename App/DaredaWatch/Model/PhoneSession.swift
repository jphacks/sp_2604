import Foundation
import Observation
import OSLog
import WatchConnectivity

/// 母艦の iPhone との通信。iPhone から届いた状態を保持し、録音ファイルと操作を iPhone に送る。
@Observable
final class PhoneSession: NSObject {
    private(set) var snapshot: WatchSnapshot = .empty
    /// iPhone に送信中の録音の数。
    private(set) var pendingTransferCount = 0
    private(set) var isReachable = false

    @ObservationIgnored private let logger = Logger(subsystem: "com.kantacky.Dareda.watchkitapp", category: "PhoneSession")
    @ObservationIgnored private let session: WCSession

    init(session: WCSession = .default) {
        self.session = session
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    /// 録音したファイルを iPhone に送る。iPhone が近くになくても、つながったときに届く。
    func transferRecording(_ url: URL, startedAt: Date, isAdditional: Bool) {
        session.transferFile(url, metadata: [
            WatchSyncKey.startedAt: startedAt.timeIntervalSince1970,
            WatchSyncKey.isAdditional: isAdditional,
        ])
        pendingTransferCount = session.outstandingFileTransfers.count
    }

    func send(_ command: WatchCommand) {
        guard let data = try? JSONEncoder().encode(command) else { return }
        session.sendMessage([WatchSyncKey.command: data], replyHandler: nil) { [logger] error in
            logger.error("Command send failed: \(error.localizedDescription)")
        }
    }

    private func apply(_ context: [String: Any]) {
        guard let data = context[WatchSyncKey.snapshot] as? Data,
              let snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data)
        else { return }
        self.snapshot = snapshot
    }
}

extension PhoneSession: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        let data = session.receivedApplicationContext[WatchSyncKey.snapshot] as? Data
        let isReachable = session.isReachable
        Task { @MainActor in
            if let data { self.apply([WatchSyncKey.snapshot: data]) }
            self.isReachable = isReachable
            if isReachable { self.send(.requestSnapshot) }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        Task { @MainActor in
            self.isReachable = isReachable
            if isReachable { self.send(.requestSnapshot) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchSyncKey.snapshot] as? Data else { return }
        Task { @MainActor in self.apply([WatchSyncKey.snapshot: data]) }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: (any Error)?) {
        let url = fileTransfer.file.fileURL
        let count = session.outstandingFileTransfers.count
        if error == nil {
            // 送り終えた録音は Apple Watch に残さない
            try? FileManager.default.removeItem(at: url)
        }
        Task { @MainActor in
            self.pendingTransferCount = count
            if let error { self.logger.error("Recording transfer failed: \(error.localizedDescription)") }
        }
    }
}

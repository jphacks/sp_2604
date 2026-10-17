import AVFoundation
import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct AudioRecorderClient: Sendable {
    enum Permission: Sendable, Equatable {
        case undetermined
        case granted
        case denied
    }

    var recordPermission: @Sendable () -> Permission = { .undetermined }
    var requestRecordPermission: @Sendable () async -> Bool = { false }
    /// 録音を開始し、録音ファイルの URL を返す。
    var start: @Sendable () async throws -> URL
    /// 録音を停止してファイルを確定し、録音済みの長さ (秒) を返す。録音中でなければ 0。
    var stop: @Sendable () -> TimeInterval = { 0 }
    var elapsedTime: @Sendable () -> TimeInterval = { 0 }
    /// システムによるオーディオセッションの無効化 (電話などによる中断) を通知する。
    var interruptions: @Sendable () -> AsyncStream<Void> = { AsyncStream { $0.finish() } }
}

nonisolated extension AudioRecorderClient: DependencyKey {
    static let liveValue: AudioRecorderClient = {
        let impl = AudioRecorderClientImpl()
        return AudioRecorderClient(
            recordPermission: impl.recordPermission,
            requestRecordPermission: impl.requestRecordPermission,
            start: impl.start,
            stop: impl.stop,
            elapsedTime: impl.elapsedTime,
            interruptions: impl.interruptions
        )
    }()

    static let testValue = AudioRecorderClient.inMemory()
    static let previewValue = AudioRecorderClient.inMemory()
}

nonisolated extension DependencyValues {
    var audioRecorderClient: AudioRecorderClient {
        get { self[AudioRecorderClient.self] }
        set { self[AudioRecorderClient.self] = newValue }
    }
}

private nonisolated struct AudioRecorderClientImpl: Sendable {
    /// 録音中の `AVAudioRecorder` のハンドルだけを保持する。
    private let handle = RecorderHandle()

    func recordPermission() -> AudioRecorderClient.Permission {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: .granted
        case .denied: .denied
        default: .undetermined
        }
    }

    func requestRecordPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "Recordings", directoryHint: .isDirectory)
            .appending(path: "\(UUID().uuidString).m4a", directoryHint: .notDirectory)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setActive(true)

        let recorder = try AVAudioRecorder(
            url: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
            ]
        )
        guard recorder.record() else {
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            throw CocoaError(.fileWriteUnknown)
        }
        handle.set(recorder)
        return url
    }

    func stop() -> TimeInterval {
        guard let recorder = handle.take() else { return 0 }
        let duration = recorder.currentTime
        recorder.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return duration
    }

    func elapsedTime() -> TimeInterval {
        handle.elapsedTime()
    }

    func interruptions() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                let notifications = NotificationCenter.default.notifications(
                    named: AVAudioSession.didBecomeInactiveNotification
                )
                for await notification in notifications {
                    let context = notification.userInfo?[AVAudioSession.deactivationContextKey]
                        as? AVAudioSession.DeactivationContext
                    // アプリ自身による deactivate は中断ではないので除外する
                    if context?.source == .system {
                        continuation.yield()
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private nonisolated final class RecorderHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var recorder: AVAudioRecorder?

    func set(_ recorder: AVAudioRecorder) {
        lock.withLock { self.recorder = recorder }
    }

    func elapsedTime() -> TimeInterval {
        lock.withLock { recorder?.currentTime ?? 0 }
    }

    func take() -> AVAudioRecorder? {
        lock.withLock {
            defer { recorder = nil }
            return recorder
        }
    }
}

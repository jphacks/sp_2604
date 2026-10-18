import AVFoundation
import Observation

/// Apple Watch のマイクでの録音。iPhone と同じ形式 (AAC・48kHz・モノラル) で録音する。
@Observable
final class WatchRecorder {
    enum State: Equatable {
        case idle
        case recording(startedAt: Date)
        case failed(String)
    }

    /// iPhone と同じ 1 回の録音の上限 (10 分)。
    static let maxDuration: TimeInterval = 600

    private(set) var state: State = .idle
    private(set) var elapsedTime: TimeInterval = 0

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var interruptionTask: Task<Void, Never>?
    @ObservationIgnored private var onFinish: ((URL, Date) -> Void)?

    var isRecording: Bool {
        if case .recording = state { true } else { false }
    }

    /// 録音を開始する。停止 (手動・上限・中断) したら `onFinish` に録音ファイルと開始時刻を渡す。
    func start(onFinish: @escaping (URL, Date) -> Void) async {
        guard !isRecording else { return }
        guard await AVAudioApplication.requestRecordPermission() else {
            state = .failed("マイクの使用が許可されていません。iPhone の Watch アプリ、または Apple Watch の設定で許可してください。")
            return
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).m4a")
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
            let recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
            ])
            guard recorder.record() else { throw CocoaError(.fileWriteUnknown) }
            self.recorder = recorder
        } catch {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            state = .failed("録音を開始できませんでした。もう一度お試しください。")
            return
        }
        let startedAt = Date.now
        self.onFinish = onFinish
        elapsedTime = 0
        state = .recording(startedAt: startedAt)
        timer = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let recorder = self.recorder else { return }
                self.elapsedTime = recorder.currentTime
                if recorder.currentTime >= Self.maxDuration {
                    self.stop()
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        interruptionTask = Task { [weak self] in
            // 電話などで中断されたら、録音済みの部分を確定する
            for await _ in NotificationCenter.default.notifications(named: AVAudioSession.interruptionNotification) {
                self?.stop()
                return
            }
        }
    }

    func stop() {
        guard case let .recording(startedAt) = state, let recorder else { return }
        timer?.cancel()
        interruptionTask?.cancel()
        recorder.stop()
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        state = .idle
        onFinish?(recorder.url, startedAt)
        onFinish = nil
    }

    /// 録音せずに破棄する。
    func discard() {
        guard isRecording, let recorder else { return }
        onFinish = nil
        let url = recorder.url
        stop()
        try? FileManager.default.removeItem(at: url)
    }

    func dismissError() {
        if case .failed = state { state = .idle }
    }
}

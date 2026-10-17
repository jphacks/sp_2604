import Dependencies
import Foundation
import Observation

@Observable
final class RecordingViewModel {
    enum Mode { case registration, search }
    enum Action {
        case onAppear
        case stopButtonTapped
        case registrationButtonTapped
        case searchButtonTapped
        case discardButtonTapped
        case discardConfirmationChanged(Bool)
        case discardConfirmed
        case retryButtonTapped
        /// 新規登録で保存した場合はそのプロフィールの ID を持つ。
        case processingFinished(Profile.ID?)
    }

    private(set) var recording: Recording?
    private(set) var isRecording = false
    private(set) var isStarting = false
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var wasInterrupted = false
    private(set) var reachedLimit = false
    private(set) var isOneMinuteRemaining = false
    private(set) var selectedMode: Mode?
    private(set) var errorMessage: LocalizedStringResource?
    private(set) var isDiscardConfirmationPresented = false
    private(set) var isFinished = false
    /// 新規登録で保存したプロフィール。閉じた後に詳細を表示するために使う。
    private(set) var registeredProfileID: Profile.ID?

    @ObservationIgnored @Dependency(\.recordingService) private var recordingService
    @ObservationIgnored @Dependency(\.requestNotificationPermissionUseCase) private var requestNotificationPermissionUseCase
    @ObservationIgnored @Dependency(\.cancelProcessingUseCase) private var cancelProcessingUseCase
    @ObservationIgnored private var elapsedTask: Task<Void, Never>?
    @ObservationIgnored private var interruptionTask: Task<Void, Never>?
    @ObservationIgnored private var hasAppeared = false
    @ObservationIgnored private var interruptedWhileStarting = false

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            guard !hasAppeared else { return }
            hasAppeared = true
            start()
        case .retryButtonTapped:
            start()
        case .stopButtonTapped:
            stop()
        case .registrationButtonTapped:
            guard recording != nil, !isRecording else { return }
            selectedMode = .registration
        case .searchButtonTapped:
            guard recording != nil, !isRecording else { return }
            selectedMode = .search
            // 検索結果を背面で受け取れるよう通知の許可を求める。拒否・失敗してもアプリ内で検索は続けられる
            Task { _ = try? await requestNotificationPermissionUseCase.execute() }
        case let .processingFinished(profileID):
            registeredProfileID = profileID
            isFinished = true
        case .discardButtonTapped:
            guard !isStarting else { return }
            isDiscardConfirmationPresented = true
        case let .discardConfirmationChanged(isPresented):
            isDiscardConfirmationPresented = isPresented
        case .discardConfirmed:
            guard !isStarting else { return }
            isDiscardConfirmationPresented = false
            stop()
            Task {
                do {
                    try await cancelProcessingUseCase.execute(recording, nil)
                    recording = nil
                    isFinished = true
                } catch {
                    errorMessage = selectedMode == nil
                        ? "録音を削除できませんでした。もう一度お試しください。"
                        : "キャンセルできませんでした。もう一度お試しください。"
                }
            }
        }
    }

    private func start() {
        guard !isStarting, recording == nil else { return }
        isStarting = true
        interruptedWhileStarting = false
        errorMessage = nil
        // start より前に中断の監視を登録し、開始直後の通知も受け取る。
        let interruptions = recordingService.interruptions()
        interruptionTask = Task { [weak self] in
            for await _ in interruptions {
                guard let self, !Task.isCancelled else { return }
                if self.isStarting {
                    self.interruptedWhileStarting = true
                }
            }
        }
        Task {
            do {
                recording = try await recordingService.start()
                isRecording = true
                if interruptedWhileStarting {
                    wasInterrupted = true
                    isStarting = false
                    stop()
                    return
                }
                guard let recording else { return }
                let events = recordingService.events(recording)
                interruptionTask?.cancel()
                isStarting = false
                elapsedTask = Task { [weak self] in
                    for await event in events {
                        guard let self, !Task.isCancelled else { return }
                        switch event {
                        case let .elapsedTimeChanged(elapsed):
                            self.elapsedTime = elapsed
                        case .oneMinuteRemaining:
                            self.isOneMinuteRemaining = true
                        case let .limitReached(stopped):
                            self.reachedLimit = true
                            self.finish(stopped)
                        case let .interrupted(stopped):
                            self.wasInterrupted = true
                            self.finish(stopped)
                        }
                    }
                }
            } catch {
                isStarting = false
                interruptionTask?.cancel()
                errorMessage = "録音を開始できませんでした。マイクを確認して、もう一度お試しください。"
            }
        }
    }

    private func finish(_ stopped: Recording) {
        recording = stopped
        elapsedTime = stopped.duration
        isRecording = false
        elapsedTask?.cancel()
        interruptionTask?.cancel()
    }

    private func stop() {
        guard isRecording, let recording else { return }
        finish(recordingService.stop(recording))
    }
}

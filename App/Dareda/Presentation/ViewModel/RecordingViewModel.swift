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
        case sceneBecameActive
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
    private(set) var analysisStage: ConversationAnalysisStage?
    private(set) var isAnalysisCompleted = false
    private(set) var isAnalysisSuspended = false
    private(set) var analysisErrorMessage: LocalizedStringResource?

    @ObservationIgnored @Dependency(\.recordingService) private var recordingService
    @ObservationIgnored @Dependency(\.processingSessionService) private var processingSessionService
    @ObservationIgnored @Dependency(\.conversationAnalysisService) private var conversationAnalysisService
    @ObservationIgnored private var session: ProcessingSession?
    @ObservationIgnored private var isAnalyzing = false
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
            analyze()
        case .searchButtonTapped:
            guard recording != nil, !isRecording else { return }
            selectedMode = .search
            analyze()
        case .sceneBecameActive:
            // OS に打ち切られた解析は、アプリに戻ったら未完了の処理だけを再試行する。
            if isAnalysisSuspended { analyze() }
        case .discardButtonTapped:
            guard !isStarting else { return }
            isDiscardConfirmationPresented = true
        case let .discardConfirmationChanged(isPresented):
            isDiscardConfirmationPresented = isPresented
        case .discardConfirmed:
            guard !isStarting else { return }
            isDiscardConfirmationPresented = false
            stop()
            do {
                if let recording { try recordingService.discard(recording) }
                recording = nil
                isFinished = true
            } catch {
                errorMessage = "録音を削除できませんでした。もう一度お試しください。"
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

    /// 第 1 段階の話者識別までを行う。同じセッションで呼び直すため、完了済みの処理は再実行されない。
    /// 処理状況の画面 (#29) と新規登録・人物検索のフロー (#21 / #23) ができるまでの暫定の呼び出し口。
    private func analyze() {
        guard let recording, !isAnalyzing, !isAnalysisCompleted else { return }
        isAnalyzing = true
        isAnalysisSuspended = false
        analysisErrorMessage = nil
        Task {
            defer {
                isAnalyzing = false
                analysisStage = nil
            }
            do {
                let session: ProcessingSession
                if let existing = self.session {
                    session = existing
                } else {
                    session = try await processingSessionService.start()
                    self.session = session
                }
                for try await event in conversationAnalysisService.analyze(recording, session) {
                    switch event {
                    case let .stageChanged(stage):
                        analysisStage = stage
                    case .completed:
                        isAnalysisCompleted = true
                    }
                }
            } catch ConversationAnalysisError.suspended {
                isAnalysisSuspended = true
            } catch {
                analysisErrorMessage = "解析に失敗しました。"
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

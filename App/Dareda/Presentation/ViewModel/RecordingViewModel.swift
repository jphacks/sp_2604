import Dependencies
import Foundation
import Observation

@Observable
final class RecordingViewModel {
    enum Action {
        case onAppear
        case stopButtonTapped
        case discardButtonTapped
        case discardConfirmationChanged(Bool)
        case discardConfirmed
        case retryButtonTapped
        /// 新規登録で保存した場合はそのプロフィールの ID を持つ。
        case processingFinished(Profile.ID?)
        case rerecordRequested
        case addButtonTapped
    }

    /// 人物検索で相手の発話が足りないときの追加録音か。追加録音では操作を選ばせず、録音を処理状況画面へ返す。
    let isAdditional: Bool
    /// ファイルアプリで選んだ音声ファイル。指定されていれば録音せずにこのファイルを取り込む。
    let importedFileURL: URL?

    private(set) var recording: Recording?
    private(set) var isRecording = false
    private(set) var isStarting = false
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var wasInterrupted = false
    private(set) var reachedLimit = false
    private(set) var isOneMinuteRemaining = false
    /// 録音の終了・ファイルの取り込みの直後に始まる音声処理を表示しているか。
    private(set) var isProcessing = false
    private(set) var errorMessage: LocalizedStringResource?
    private(set) var isDiscardConfirmationPresented = false
    private(set) var isFinished = false
    /// 新規登録で保存したプロフィール。閉じた後に詳細を表示するために使う。
    private(set) var registeredProfileID: Profile.ID?
    /// 追加録音で「追加する」を選んだ録音。
    private(set) var addedRecording: Recording?

    @ObservationIgnored @Dependency(\.recordingService) private var recordingService
    @ObservationIgnored @Dependency(\.requestNotificationPermissionUseCase) private var requestNotificationPermissionUseCase
    @ObservationIgnored @Dependency(\.cancelProcessingUseCase) private var cancelProcessingUseCase
    @ObservationIgnored @Dependency(\.recordingActivityService) private var recordingActivityService
    @ObservationIgnored @Dependency(\.appIntentRequestService) private var appIntentRequestService
    @ObservationIgnored private var elapsedTask: Task<Void, Never>?
    @ObservationIgnored private var interruptionTask: Task<Void, Never>?
    /// Live Activity・ショートカットからの録音終了の依頼の監視。
    @ObservationIgnored private var stopRequestTask: Task<Void, Never>?
    /// コントロール・ショートカットからの録音開始の依頼の監視。
    @ObservationIgnored private var startRequestTask: Task<Void, Never>?
    /// Live Activity の更新を順番に反映するため、直前の更新を待ってから次を反映する。
    @ObservationIgnored private var activityTask: Task<Void, Never>?
    @ObservationIgnored private var hasAppeared = false
    @ObservationIgnored private var interruptedWhileStarting = false

    init(isAdditional: Bool = false, importedFileURL: URL? = nil) {
        self.isAdditional = isAdditional
        self.importedFileURL = importedFileURL
    }

    var isImported: Bool { importedFileURL != nil }

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            guard !hasAppeared else { return }
            hasAppeared = true
            observeStartRequests()
            startOrImport()
        case .retryButtonTapped:
            startOrImport()
        case .stopButtonTapped:
            stop()
        case .addButtonTapped:
            guard isAdditional, let recording, !isRecording else { return }
            addedRecording = recording
            isFinished = true
        case let .processingFinished(profileID):
            registeredProfileID = profileID
            isFinished = true
        case .rerecordRequested:
            // 前の録音と処理データは処理状況画面で削除済み。処理前の状態に戻して新しく録音する
            resetForRerecord()
            start()
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
                    if !isAdditional { endActivity() }
                    isFinished = true
                } catch {
                    errorMessage = !isProcessing
                        ? "録音を削除できませんでした。もう一度お試しください。"
                        : "キャンセルできませんでした。もう一度お試しください。"
                }
            }
        }
    }

    private func resetForRerecord() {
        recording = nil
        isProcessing = false
        elapsedTime = 0
        wasInterrupted = false
        reachedLimit = false
        isOneMinuteRemaining = false
        errorMessage = nil
    }

    /// 録音中・録音前の依頼では、録音を破棄して新しく始める。処理中の依頼は処理状況画面が受け取る。
    private func observeStartRequests() {
        let requests = appIntentRequestService.requests()
        startRequestTask = Task { [weak self] in
            for await request in requests where request == .startRecording {
                guard let self, !Task.isCancelled else { return }
                self.restart()
            }
        }
    }

    private func restart() {
        guard !isAdditional, !isProcessing, !isStarting, !isFinished else { return }
        guard isRecording, let recording else {
            // 録音を開始できていない状態からは、そのまま録音し直す
            if self.recording == nil { start() }
            return
        }
        elapsedTask?.cancel()
        interruptionTask?.cancel()
        stopRequestTask?.cancel()
        isRecording = false
        let stopped = recordingService.stop(recording)
        Task {
            // 削除できなかった一時データは、次回の起動時の掃除で消える
            try? await cancelProcessingUseCase.execute(stopped, nil)
            resetForRerecord()
            start()
        }
    }

    private func startOrImport() {
        if let importedFileURL {
            importFile(importedFileURL)
        } else {
            start()
        }
    }

    private func importFile(_ url: URL) {
        guard recording == nil else { return }
        errorMessage = nil
        do {
            let imported = try recordingService.importFile(url)
            recording = imported
            elapsedTime = imported.duration
            startProcessing()
        } catch {
            errorMessage = "音声ファイルを読み込めませんでした。別のファイルを選んでください。"
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
                if !isAdditional {
                    let startedAt = Date.now.addingTimeInterval(-elapsedTime)
                    // App Intent から始めたときは Intent の実行中に Live Activity を表示済み。
                    // バックグラウンドでは新しく表示できないため、閉じて作り直さず更新する
                    updateActivity { await $0.update(.recording(startedAt: startedAt)) }
                }
                observeStopRequests()
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
        stopRequestTask?.cancel()
        startProcessing()
    }

    /// 録音の終了・ファイルの取り込み後すぐに音声処理を始める。追加録音は処理状況画面へ返すため始めない。
    private func startProcessing() {
        guard !isAdditional, !isProcessing else { return }
        isProcessing = true
        updateActivity { await $0.update(.analyzing(stage: ConversationAnalysisStage.transcribing.label)) }
        // 結果を背面で受け取れるよう通知の許可を求める。拒否・失敗してもアプリ内で処理は続けられる
        Task { _ = try? await requestNotificationPermissionUseCase.execute() }
    }

    private func stop() {
        guard isRecording, let recording else { return }
        finish(recordingService.stop(recording))
    }

    /// Live Activity の停止ボタンやショートカットから録音を終了できるようにする。
    private func observeStopRequests() {
        let requests = appIntentRequestService.requests()
        stopRequestTask = Task { [weak self] in
            for await request in requests where request == .stopRecording {
                guard let self, !Task.isCancelled else { return }
                self.send(.stopButtonTapped)
            }
        }
    }

    private func updateActivity(_ operation: @escaping (RecordingActivityService) async -> Void) {
        let previous = activityTask
        let service = recordingActivityService
        activityTask = Task {
            await previous?.value
            await operation(service)
        }
    }

    private func endActivity() {
        updateActivity { await $0.end() }
    }
}

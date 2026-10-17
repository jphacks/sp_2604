import Dependencies
import Foundation
import Observation

@Observable
final class ProcessingViewModel {
    enum Action {
        case onAppear
        case retryButtonTapped
        case cancelButtonTapped
        case cancelConfirmationChanged(Bool)
        case cancelConfirmed
        case sceneBecameActive
        case registrationSaved(Profile.ID)
        case selfSpeakerSelected(AnalyzedSpeaker.ID)
        case rerecordButtonTapped
    }

    enum StageStatus { case waiting, processing, completed, failed }

    let mode: RecordingViewModel.Mode
    let stages: [ConversationAnalysisStage]
    private(set) var currentStage: ConversationAnalysisStage?
    private(set) var completedStages: [ConversationAnalysisStage] = []
    private(set) var failedStage: ConversationAnalysisStage?
    private(set) var errorMessage: LocalizedStringResource?
    private(set) var isCompleted = false
    private(set) var isSuspended = false
    /// 本人を自動判定できず、手動選択が必要なときの解析結果。
    private(set) var selfSelectionAnalysis: ConversationAnalysis?
    private(set) var isRerecordRequested = false
    private(set) var isCancelConfirmationPresented = false
    private(set) var isFinished = false
    /// 新規登録の入力に進める解析結果。本人と相手の声がそろい、要約が済んだときだけ値を持つ。
    private(set) var registrationSource: RegistrationViewModel.Source?
    /// 新規登録で保存したプロフィール。閉じた後に詳細を表示するために使う。
    private(set) var registeredProfileID: Profile.ID?

    @ObservationIgnored @Dependency(\.processingSessionService) private var processingSessionService
    @ObservationIgnored @Dependency(\.conversationAnalysisService) private var conversationAnalysisService
    @ObservationIgnored @Dependency(\.searchPersonUseCase) private var searchPersonUseCase
    @ObservationIgnored @Dependency(\.cancelProcessingUseCase) private var cancelProcessingUseCase
    @ObservationIgnored private let recording: Recording
    @ObservationIgnored private var session: ProcessingSession?
    /// 手動で選んだ本人の話者。再試行時も引き継ぐ。
    @ObservationIgnored private var selfSpeakerID: AnalyzedSpeaker.ID?
    @ObservationIgnored private var processingTask: Task<Void, Never>?
    @ObservationIgnored private var hasAppeared = false

    init(recording: Recording, mode: RecordingViewModel.Mode) {
        self.recording = recording
        self.mode = mode
        stages = switch mode {
        case .registration: [.transcribing, .identifyingSpeakers, .summarizing]
        case .search: [.transcribing, .identifyingSpeakers]
        }
    }

    func status(of stage: ConversationAnalysisStage) -> StageStatus {
        if completedStages.contains(stage) { return .completed }
        if failedStage == stage { return .failed }
        if currentStage == stage { return .processing }
        return .waiting
    }

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            guard !hasAppeared else { return }
            hasAppeared = true
            process()
        case .retryButtonTapped:
            process()
        case .sceneBecameActive:
            // OS に打ち切られた解析は、アプリに戻ったら未完了の処理だけを再試行する。
            if isSuspended { process() }
        case let .registrationSaved(profileID):
            registeredProfileID = profileID
            isFinished = true
        case .cancelButtonTapped:
            isCancelConfirmationPresented = true
        case let .cancelConfirmationChanged(isPresented):
            isCancelConfirmationPresented = isPresented
        case .cancelConfirmed:
            isCancelConfirmationPresented = false
            discard {
                self.isFinished = true
            } onFailure: {
                self.errorMessage = "キャンセルできませんでした。もう一度お試しください。"
            }
        case let .selfSpeakerSelected(speakerID):
            guard selfSelectionAnalysis?.speakers.contains(where: { $0.id == speakerID }) == true else { return }
            selfSpeakerID = speakerID
            selfSelectionAnalysis = nil
            process()
        case .rerecordButtonTapped:
            discard {
                self.isRerecordRequested = true
            } onFailure: {
                self.errorMessage = "録音を削除できませんでした。もう一度お試しください。"
            }
        }
    }

    /// 処理を止め、録音と処理セッションの一時データを削除する。
    private func discard(onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        processingTask?.cancel()
        Task {
            do {
                try await cancelProcessingUseCase.execute(recording, session)
                onSuccess()
            } catch {
                onFailure()
            }
        }
    }

    /// 同じセッションで呼び直すため、成功済みの処理は Service 側で再実行されない。
    private func process() {
        guard processingTask == nil else { return }
        failedStage = nil
        errorMessage = nil
        isSuspended = false
        processingTask = Task {
            defer { processingTask = nil }
            do {
                let session = try await currentSession()
                switch mode {
                case .registration:
                    try await register(session)
                case .search:
                    try await search(session)
                }
            } catch is CancellationError {
                return
            } catch ConversationAnalysisError.suspended {
                isSuspended = true
            } catch let PersonSearchError.selfNotIdentified(analysis) {
                completeCurrentStage()
                selfSelectionAnalysis = analysis
            } catch {
                guard !Task.isCancelled else { return }
                failedStage = currentStage ?? stages.first
                errorMessage = Self.message(for: error)
            }
        }
    }

    private func currentSession() async throws -> ProcessingSession {
        if let session { return session }
        let session = try await processingSessionService.start()
        self.session = session
        return session
    }

    private func register(_ session: ProcessingSession) async throws {
        var analysis: ConversationAnalysis?
        for try await event in conversationAnalysisService.analyze(recording, session) {
            switch event {
            case let .stageChanged(stage): stageChanged(stage)
            case let .completed(value): analysis = value
            }
        }
        guard let analysis else { throw CancellationError() }
        guard let selfSpeakerID = selfSpeakerID ?? analysis.selfSpeakerID else {
            completeCurrentStage()
            selfSelectionAnalysis = analysis
            return
        }
        guard let partnerVector = analysis.partner(selfSpeakerID: selfSpeakerID)?.embedding?.values else {
            // 再試行しても結果は変わらないため、録音し直してもらう
            completeCurrentStage()
            errorMessage = "相手の声を検出できなかったため登録できません。キャンセルして録音し直してください。"
            return
        }
        let transcript = analysis.transcript(selfSpeakerID: selfSpeakerID)
        for try await event in conversationAnalysisService.summarize(transcript, session) {
            switch event {
            case let .stageChanged(stage): stageChanged(stage)
            case let .completed(summary):
                complete()
                registrationSource = RegistrationViewModel.Source(
                    recording: recording,
                    session: session,
                    summary: summary.text,
                    partnerVector: partnerVector
                )
            }
        }
    }

    private func search(_ session: ProcessingSession) async throws {
        for try await event in searchPersonUseCase.search([
            PersonSearchRecording(recording: recording, session: session, selfSpeakerID: selfSpeakerID)
        ]) {
            switch event {
            case let .stageChanged(stage): stageChanged(stage)
            case .completed: complete()
            }
        }
    }

    private func stageChanged(_ stage: ConversationAnalysisStage) {
        if let currentStage, currentStage != stage, !completedStages.contains(currentStage) {
            completedStages.append(currentStage)
        }
        currentStage = stage
    }

    private func completeCurrentStage() {
        if let currentStage, !completedStages.contains(currentStage) {
            completedStages.append(currentStage)
        }
        currentStage = nil
    }

    private func complete() {
        completeCurrentStage()
        // キャッシュ済みで通知されなかった処理も完了として扱う
        completedStages = stages
        isCompleted = true
    }

    private static func message(for error: any Error) -> LocalizedStringResource {
        switch error {
        case ConversationAnalysisError.noSpeakerDetected:
            "話している人を判別できませんでした。もう一度お試しいただくか、キャンセルして録音し直してください。"
        case PersonSearchError.partnerNotDetected:
            "相手の声を検出できませんでした。もう一度お試しいただくか、キャンセルして録音し直してください。"
        default:
            "処理に失敗しました。もう一度お試しください。"
        }
    }
}

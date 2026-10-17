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
    private(set) var needsSelfSelection = false
    private(set) var isCancelConfirmationPresented = false
    private(set) var isFinished = false

    @ObservationIgnored @Dependency(\.processingSessionService) private var processingSessionService
    @ObservationIgnored @Dependency(\.conversationAnalysisService) private var conversationAnalysisService
    @ObservationIgnored @Dependency(\.searchPersonUseCase) private var searchPersonUseCase
    @ObservationIgnored @Dependency(\.cancelProcessingUseCase) private var cancelProcessingUseCase
    @ObservationIgnored private let recording: Recording
    @ObservationIgnored private var session: ProcessingSession?
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
        case .cancelButtonTapped:
            isCancelConfirmationPresented = true
        case let .cancelConfirmationChanged(isPresented):
            isCancelConfirmationPresented = isPresented
        case .cancelConfirmed:
            isCancelConfirmationPresented = false
            processingTask?.cancel()
            Task {
                do {
                    try await cancelProcessingUseCase.execute(recording, session)
                    isFinished = true
                } catch {
                    errorMessage = "キャンセルできませんでした。もう一度お試しください。"
                }
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
            } catch PersonSearchError.selfNotIdentified {
                completeCurrentStage()
                needsSelfSelection = true
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
        guard let selfSpeakerID = analysis.selfSpeakerID else {
            completeCurrentStage()
            needsSelfSelection = true
            return
        }
        for try await event in conversationAnalysisService.summarize(
            analysis.transcript(selfSpeakerID: selfSpeakerID), session
        ) {
            switch event {
            case let .stageChanged(stage): stageChanged(stage)
            case .completed: complete()
            }
        }
    }

    private func search(_ session: ProcessingSession) async throws {
        for try await event in searchPersonUseCase.search([PersonSearchRecording(recording: recording, session: session)]) {
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

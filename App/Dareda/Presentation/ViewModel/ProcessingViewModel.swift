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
        case candidateSelected(Profile.ID)
        case manualSelectionButtonTapped
        case manualSelectionPresentedChanged(Bool)
        case newRegistrationButtonTapped
        case overwriteButtonTapped(Profile.ID)
        case overwriteConfirmationPresentedChanged(Bool)
        case overwriteConfirmed(Profile.ID)
        case additionalRecordingButtonTapped
        case additionalRecordingPresentedChanged(Bool)
        case additionalRecordingAdded(Recording)
    }

    enum StageStatus { case waiting, processing, completed, failed }

    let stages: [ConversationAnalysisStage] = [.transcribing, .identifyingSpeakers, .summarizing]
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
    /// 新規登録の入力に進める解析結果。「該当なし・新規登録」を選んだときに値を持つ。
    private(set) var registrationSource: RegistrationViewModel.Source?
    /// 新規登録で保存した、または人物検索で確定したプロフィール。閉じた後に詳細を表示するために使う。
    private(set) var registeredProfileID: Profile.ID?
    /// 人物検索の候補 (類似度の高い順)。照合が済むまでは `nil`、登録済みの人物がいなければ空。
    private(set) var searchCandidates: [ProfileDetailServiceModel]?
    /// 相手の有効発話が足りず、追加録音を促すときの、これまでの相手の有効発話時間 (秒)。
    private(set) var insufficientPartnerSpeechDuration: TimeInterval?
    private(set) var isAdditionalRecordingPresented = false
    private(set) var isManualSelectionPresented = false
    /// 手動選択で選べる保存済みのプロフィール。
    private(set) var manualSelectionProfiles: [Profile] = []
    /// 人物の確定 (一時データの削除) 中。
    private(set) var isConfirming = false
    /// 最新の会話で前回の会話を上書きできるか。要約まで済んでいる (`pendingRegistration` がある) ときだけ上書きできる。
    private(set) var canOverwrite = false
    /// 候補を提示した後で、今回の会話の要約を作成中。
    private(set) var isSummarizing = false
    /// 今回の会話の日時と要約。要約の作成が済むまで要約は `nil`。上書きの提案に表示する。
    var latestMetAt: Date { recording.startedAt }
    var latestSummary: String? { canOverwrite ? pendingRegistration?.summary : nil }
    private(set) var isOverwriteConfirmationPresented = false

    @ObservationIgnored @Dependency(\.processingSessionService) private var processingSessionService
    @ObservationIgnored @Dependency(\.conversationAnalysisService) private var conversationAnalysisService
    @ObservationIgnored @Dependency(\.searchPersonUseCase) private var searchPersonUseCase
    @ObservationIgnored @Dependency(\.cancelProcessingUseCase) private var cancelProcessingUseCase
    @ObservationIgnored @Dependency(\.completePersonSearchUseCase) private var completePersonSearchUseCase
    @ObservationIgnored @Dependency(\.notifyPersonSearchResultUseCase) private var notifyPersonSearchResultUseCase
    @ObservationIgnored @Dependency(\.fetchProfileDetailUseCase) private var fetchProfileDetailUseCase
    @ObservationIgnored @Dependency(\.fetchProfilesUseCase) private var fetchProfilesUseCase
    @ObservationIgnored @Dependency(\.watchSyncService) private var watchSyncService
    @ObservationIgnored @Dependency(\.recordingService) private var recordingService
    @ObservationIgnored @Dependency(\.overwriteEncounterUseCase) private var overwriteEncounterUseCase
    @ObservationIgnored @Dependency(\.registerProfileUseCase) private var registerProfileUseCase
    @ObservationIgnored @Dependency(\.searchPlacesUseCase) private var searchPlacesUseCase
    /// Apple Watch で入力した場所の検索結果。
    private var watchPlaceCandidates: [Place] = []
    /// Apple Watch からの新規登録の保存に失敗したときのメッセージ。
    private var watchRegistrationErrorMessage: String?
    @ObservationIgnored private var isRegisteringFromWatch = false
    @ObservationIgnored @Dependency(\.recordingActivityService) private var recordingActivityService
    @ObservationIgnored private let recording: Recording
    @ObservationIgnored private var session: ProcessingSession?
    /// 手動で選んだ本人の話者。再試行時も引き継ぐ。
    @ObservationIgnored private var selfSpeakerID: AnalyzedSpeaker.ID?
    /// 人物検索の追加録音。最初の録音とあわせて照合する。
    @ObservationIgnored private var additionalRecordings: [PersonSearchRecording] = []
    /// 人物検索から新規登録へ進んだか。
    @ObservationIgnored private var isRegisteringFromSearch = false
    /// 人物検索と同時に済ませた要約。新規登録に進むときに入力の初期値として渡す。
    @ObservationIgnored private var pendingRegistration: RegistrationViewModel.Source?
    /// 本人を手動選択している録音。
    @ObservationIgnored private var selfSelectionRecordingID: Recording.ID?
    @ObservationIgnored private var processingTask: Task<Void, Never>?
    /// Live Activity の更新を順番に反映するため、直前の更新を待ってから次を反映する。
    @ObservationIgnored private var activityTask: Task<Void, Never>?
    /// 人物検索の結果を Live Activity に表示したか。表示後の要約の進捗では Live Activity を戻さない。
    @ObservationIgnored private var isActivityResultShown = false
    @ObservationIgnored private var hasAppeared = false
    @ObservationIgnored @Dependency(\.appIntentRequestService) private var appIntentRequestService

    init(recording: Recording) {
        self.recording = recording
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
            observeForWatch()
            observeWatchOperations()
            observeStartRequests()
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
            if let index = additionalRecordings.firstIndex(where: { $0.recording.id == selfSelectionRecordingID }) {
                additionalRecordings[index].selfSpeakerID = speakerID
            } else {
                selfSpeakerID = speakerID
            }
            selfSelectionRecordingID = nil
            selfSelectionAnalysis = nil
            process()
        case let .candidateSelected(profileID):
            confirm(profileID)
        case .manualSelectionButtonTapped:
            isManualSelectionPresented = true
            Task {
                // 読み込めなくても一覧が空になるだけで、他の選択肢は選べる
                manualSelectionProfiles = (try? await fetchProfilesUseCase.execute()) ?? []
            }
        case let .manualSelectionPresentedChanged(isPresented):
            isManualSelectionPresented = isPresented
        case .newRegistrationButtonTapped:
            // 要約の作成中は、完了を待って新規登録の初期値に使う
            guard !isRegisteringFromSearch, !isSummarizing else { return }
            isRegisteringFromSearch = true
            // 新規登録には最初の録音だけを使うため、追加録音の一時データは先に削除する
            let additional = additionalRecordings
            additionalRecordings = []
            Task {
                try? await completePersonSearchUseCase.execute(additional)
                if let pendingRegistration {
                    registrationSource = pendingRegistration
                } else {
                    // 発話不足などで要約が済んでいないため、ここで要約まで行う
                    searchCandidates = nil
                    insufficientPartnerSpeechDuration = nil
                    isCompleted = false
                    completedStages = [.transcribing, .identifyingSpeakers]
                    process()
                }
            }
        case .overwriteButtonTapped:
            isOverwriteConfirmationPresented = true
        case let .overwriteConfirmationPresentedChanged(isPresented):
            isOverwriteConfirmationPresented = isPresented
        case let .overwriteConfirmed(profileID):
            isOverwriteConfirmationPresented = false
            overwrite(profileID)
        case .additionalRecordingButtonTapped:
            isAdditionalRecordingPresented = true
        case let .additionalRecordingPresentedChanged(isPresented):
            isAdditionalRecordingPresented = isPresented
        case let .additionalRecordingAdded(added):
            isAdditionalRecordingPresented = false
            Task {
                do {
                    let session = try await processingSessionService.start()
                    additionalRecordings.append(PersonSearchRecording(recording: added, session: session, selfSpeakerID: nil))
                    isActivityResultShown = false
                    insufficientPartnerSpeechDuration = nil
                    isCompleted = false
                    completedStages = []
                    process()
                } catch {
                    // 追加録音の案内は残したまま、もう一度録音できるようにする
                    try? await cancelProcessingUseCase.execute(added, nil)
                    errorMessage = "追加録音を処理できませんでした。もう一度お試しください。"
                }
            }
        case .rerecordButtonTapped:
            discard {
                self.isRerecordRequested = true
            } onFailure: {
                self.errorMessage = "録音を削除できませんでした。もう一度お試しください。"
            }
        }
    }

    /// コントロール・ショートカットから録音の開始を依頼されたら、処理を破棄して録音し直す。
    private func observeStartRequests() {
        let requests = appIntentRequestService.requests()
        Task { [weak self] in
            for await request in requests where request == .startRecording {
                guard let self else { return }
                guard !self.isFinished, !self.isRerecordRequested else { continue }
                self.send(.rerecordButtonTapped)
            }
        }
    }

    /// Apple Watch に表示する処理状況。
    private var watchState: WatchProcessingState? {
        if isFinished {
            guard let registeredProfileID else { return nil }
            let profile = searchCandidates?.first { $0.profile.id == registeredProfileID }.map(WatchProfile.init)
            return .completed(profile)
        }
        if let errorMessage { return .failed(message: String(localized: errorMessage)) }
        if let selfSelectionAnalysis {
            return .selectSelf(selfSelectionAnalysis.speakers.map { speaker in
                WatchSpeaker(id: speaker.id, speeches: selfSelectionAnalysis.speeches(of: speaker.id).map(\.text))
            })
        }
        if let registrationSource {
            return .registration(WatchRegistrationDraft(
                summary: registrationSource.summary,
                metAt: registrationSource.recording.startedAt,
                placeCandidates: watchPlaceCandidates.map(WatchPlace.init),
                errorMessage: watchRegistrationErrorMessage
            ))
        }
        if isSuspended || isManualSelectionPresented { return .needsInputOnPhone }
        if insufficientPartnerSpeechDuration != nil { return .needsAdditionalRecording }
        if isCompleted, let searchCandidates { return .candidates(searchCandidates.map(WatchProfile.init)) }
        return .processing(WatchProcessingStage(currentStage ?? .transcribing))
    }

    /// 処理状況が変わるたびに Apple Watch へ送る。
    private func observeForWatch() {
        let state = withObservationTracking { watchState } onChange: { [weak self] in
            Task { @MainActor in self?.observeForWatch() }
        }
        watchSyncService.updateProcessing(state)
    }

    /// Apple Watch での候補の確定・キャンセル・追加録音を受け取る。
    private func observeWatchOperations() {
        let commands = watchSyncService.commands()
        Task { [weak self] in
            for await command in commands {
                guard let self, !self.isFinished else { return }
                switch command {
                case let .selectCandidate(profileID):
                    guard self.searchCandidates?.contains(where: { $0.profile.id == profileID }) == true else { continue }
                    self.confirm(profileID)
                case .cancelProcessing:
                    self.send(.cancelConfirmed)
                case .retryProcessing:
                    self.send(.retryButtonTapped)
                case let .selectSelf(speakerID):
                    self.send(.selfSpeakerSelected(speakerID))
                case .startNewRegistration:
                    guard self.searchCandidates != nil || self.insufficientPartnerSpeechDuration != nil else { continue }
                    self.send(.newRegistrationButtonTapped)
                case let .searchPlaces(query):
                    // 失敗しても入力し直す以外にできることがないため、候補を空にする
                    self.watchPlaceCandidates = (try? await self.searchPlacesUseCase.execute(query)) ?? []
                case let .register(name, affiliation, summary, place):
                    await self.registerFromWatch(name: name, affiliation: affiliation, summary: summary, place: place)
                case .setPrivateCloudComputeEnabled:
                    break
                case .requestSnapshot:
                    self.watchSyncService.updateProcessing(self.watchState)
                }
            }
        }
        let recordings = watchSyncService.recordings()
        Task { [weak self] in
            for await recording in recordings where recording.kind == .additional {
                guard let self, !self.isFinished, self.insufficientPartnerSpeechDuration != nil else { continue }
                // ファイルアプリの音声ファイルと同じように取り込み、iPhone で追加録音したときと同様に処理する
                guard let added = try? self.recordingService.importFile(recording.fileURL) else {
                    self.errorMessage = "追加録音を処理できませんでした。もう一度お試しください。"
                    continue
                }
                self.send(.additionalRecordingAdded(added))
            }
        }
    }

    /// Apple Watch で入力した内容で新規登録を保存する。iPhone の入力画面と同じ処理で保存する。
    private func registerFromWatch(name: String, affiliation: String, summary: String, place: WatchPlace?) async {
        guard let registrationSource, !isRegisteringFromWatch,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        isRegisteringFromWatch = true
        defer { isRegisteringFromWatch = false }
        watchRegistrationErrorMessage = nil
        do {
            let profileID = try await registerProfileUseCase.execute(
                name, affiliation, registrationSource.recording.startedAt,
                place.map { Place(name: $0.name, latitude: $0.latitude, longitude: $0.longitude) },
                summary, registrationSource.partnerVector, registrationSource.recording, registrationSource.session
            )
            send(.registrationSaved(profileID))
        } catch {
            watchRegistrationErrorMessage = String(localized: "保存できませんでした。もう一度お試しください。")
        }
    }

    /// 人物検索で既存の人物を確定する。一時データを削除し、そのプロフィールの詳細を表示する。
    private func confirm(_ profileID: Profile.ID) {
        guard !isConfirming else { return }
        isConfirming = true
        isManualSelectionPresented = false
        errorMessage = nil
        Task {
            defer { isConfirming = false }
            do {
                try await completePersonSearchUseCase.execute(try await searchRecordings())
                registeredProfileID = profileID
                isFinished = true
            } catch {
                errorMessage = "確定できませんでした。もう一度お試しください。"
            }
        }
    }

    /// 人物検索で見つかった人物の前回の会話を、この録音の日時と要約で上書きして確定する。
    private func overwrite(_ profileID: Profile.ID) {
        guard !isConfirming, let pendingRegistration else { return }
        isConfirming = true
        errorMessage = nil
        Task {
            defer { isConfirming = false }
            do {
                try await overwriteEncounterUseCase.execute(
                    profileID, pendingRegistration.recording.startedAt, pendingRegistration.summary
                )
            } catch {
                errorMessage = "上書きできませんでした。もう一度お試しください。"
                return
            }
            // 上書きは済んでいるため、一時データの削除に失敗しても確定扱いにして二重に上書きさせない
            try? await completePersonSearchUseCase.execute(try await searchRecordings())
            registeredProfileID = profileID
            isFinished = true
        }
    }

    /// 処理を止め、録音と処理セッションの一時データを削除する。
    private func discard(onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        processingTask?.cancel()
        Task {
            do {
                try await cancelProcessingUseCase.execute(recording, session)
                try await completePersonSearchUseCase.execute(additionalRecordings)
                additionalRecordings = []
                updateActivity { await $0.end() }
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
                if isRegisteringFromSearch {
                    try await register(session)
                } else {
                    try await search(session)
                }
            } catch is CancellationError {
                return
            } catch ConversationAnalysisError.suspended {
                isSuspended = true
            } catch let PersonSearchError.selfNotIdentified(analysis, recordingID) {
                completeCurrentStage()
                selfSelectionRecordingID = recordingID
                selfSelectionAnalysis = analysis
                updateActivity { await $0.update(.needsSelfSelection) }
            } catch {
                guard !Task.isCancelled else { return }
                failedStage = currentStage ?? stages.first
                errorMessage = Self.message(for: error)
                updateActivity { await $0.update(.failed) }
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
            updateActivity { await $0.update(.needsSelfSelection) }
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

    private func searchRecordings() async throws -> [PersonSearchRecording] {
        let first = PersonSearchRecording(recording: recording, session: try await currentSession(), selfSpeakerID: selfSpeakerID)
        return [first] + additionalRecordings
    }

    private func search(_ session: ProcessingSession) async throws {
        for try await event in searchPersonUseCase.search(try await searchRecordings()) {
            switch event {
            case let .stageChanged(stage): stageChanged(stage)
            case let .completed(result):
                switch result {
                case let .needsAdditionalRecording(duration):
                    notifyResult(result)
                    isActivityResultShown = true
                    updateActivity { await $0.update(.needsAdditionalRecording) }
                    completeCurrentStage()
                    completedStages = stages
                    insufficientPartnerSpeechDuration = duration
                case let .candidates(matches):
                    var details: [ProfileDetailServiceModel] = []
                    for match in matches {
                        if let detail = try await fetchProfileDetailUseCase.execute(match.profileID) {
                            details.append(detail)
                        }
                    }
                    let activity: RecordingActivity =
                        if let first = details.first { .candidate(first.profile, first.encounter) } else { .noCandidate }
                    isActivityResultShown = true
                    updateActivity { await $0.update(activity) }
                    // 要約より先に候補を提示し、要約は新規登録の初期値と上書きの提案のために続けて作成する
                    notifyResult(result)
                    searchCandidates = details
                    try await prepareRegistration(session)
                    complete()
                }
            }
        }
    }

    /// アプリ表示中は通知されない。通知できなくても結果はアプリ内で確認できる。
    private func notifyResult(_ result: PersonSearchResult) {
        Task { try? await notifyPersonSearchResultUseCase.execute(result) }
    }

    /// 最初の録音の相手の声と要約を、新規登録に進めるよう保持する。解析結果は保存済みのため再実行されない。
    /// 最初の録音から相手を検出できなかった場合 (追加録音でのみ検出) は何も保持しない。
    private func prepareRegistration(_ session: ProcessingSession) async throws {
        pendingRegistration = nil
        canOverwrite = false
        isSummarizing = true
        defer { isSummarizing = false }
        var analysis: ConversationAnalysis?
        for try await event in conversationAnalysisService.analyze(recording, session) {
            if case let .completed(value) = event { analysis = value }
        }
        guard let analysis,
              let selfSpeakerID = selfSpeakerID ?? analysis.selfSpeakerID,
              let partnerVector = analysis.partner(selfSpeakerID: selfSpeakerID)?.embedding?.values
        else { return }
        for try await event in conversationAnalysisService.summarize(analysis.transcript(selfSpeakerID: selfSpeakerID), session) {
            switch event {
            case let .stageChanged(stage): stageChanged(stage)
            case let .completed(summary):
                pendingRegistration = RegistrationViewModel.Source(
                    recording: recording,
                    session: session,
                    summary: summary.text,
                    partnerVector: partnerVector
                )
                canOverwrite = true
            }
        }
    }

    private func stageChanged(_ stage: ConversationAnalysisStage) {
        if let currentStage, currentStage != stage, !completedStages.contains(currentStage) {
            completedStages.append(currentStage)
        }
        currentStage = stage
        // 新規登録の要約はアプリ内で進めるため、人物検索の結果を表示した後は Live Activity を戻さない
        if !isRegisteringFromSearch, !isActivityResultShown {
            updateActivity { await $0.update(.analyzing(stage: stage.label)) }
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

private extension WatchProcessingStage {
    init(_ stage: ConversationAnalysisStage) {
        switch stage {
        case .transcribing: self = .transcribing
        case .identifyingSpeakers: self = .identifyingSpeakers
        case .summarizing: self = .summarizing
        }
    }
}

private extension WatchPlace {
    init(_ place: Place) {
        self.init(name: place.name, latitude: place.latitude, longitude: place.longitude)
    }
}

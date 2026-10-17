import Foundation
import Dependencies
import Observation

@Observable
final class RootViewModel {
    enum Action {
        case onAppear
        case recordButtonTapped
        case recordingSourceSelectionChanged(Bool)
        case recordFromMicrophoneTapped
        case chooseAudioFileTapped
        case fileImporterPresentedChanged(Bool)
        case audioFileSelected(URL)
        case settingsButtonTapped
        case alertDismissed
        case settingsMenuButtonTapped
        case settingsPresentedChanged(Bool)
        /// 新規登録で保存した場合はそのプロフィールの ID を持つ。
        case recordingFinished(Profile.ID?)
        case preparationRetryButtonTapped
        case voiceEnrollmentCompleted
        case personSearchNotificationTapped
        /// Apple Watch で録音したファイルが届いた。
        case watchRecordingReceived(URL)
    }

    enum Alert: Equatable {
        case microphoneDenied
        case preparationFailed
    }

    private(set) var isRequestingPermission = false
    private(set) var alert: Alert?

    private(set) var availability: DeviceAvailability?
    private(set) var isSettingsPresented = false
    private(set) var isRecordingPresented = false
    /// 録音するかファイルアプリから選ぶかの選択肢を表示しているか。
    private(set) var isRecordingSourceSelectionPresented = false
    private(set) var isFileImporterPresented = false
    /// ファイルアプリで選んだ音声ファイル。録音画面で録音の代わりに取り込む。
    private(set) var importedFileURL: URL?
    private(set) var isPreparedForRecording = false
    private(set) var isVoiceEnrollmentPresented = false
    /// 直近の新規登録で保存したプロフィール。一覧からその詳細を表示する。
    private(set) var registeredProfileID: Profile.ID?

    @ObservationIgnored
    @Dependency(\.cleanUpTemporaryDataUseCase) private var cleanUpTemporaryDataUseCase
    @ObservationIgnored
    @Dependency(\.checkDeviceAvailabilityUseCase) private var checkDeviceAvailabilityUseCase
    @ObservationIgnored
    @Dependency(\.fetchSelfVoiceRegisteredUseCase) private var fetchSelfVoiceRegisteredUseCase
    @ObservationIgnored
    @Dependency(\.requestRecordingPermissionUseCase) private var requestRecordingPermissionUseCase
    @ObservationIgnored
    @Dependency(\.openAppSettingsUseCase) private var openAppSettingsUseCase
    @ObservationIgnored
    @Dependency(\.observePersonSearchNotificationTapUseCase) private var observePersonSearchNotificationTapUseCase
    @ObservationIgnored
    @Dependency(\.watchSyncService) private var watchSyncService
    @ObservationIgnored
    @Dependency(\.registerSelfVoiceUseCase) private var registerSelfVoiceUseCase
    @ObservationIgnored
    @Dependency(\.fetchSelfVoiceUseCase) private var fetchSelfVoiceUseCase
    @ObservationIgnored
    @Dependency(\.fetchPrivateCloudComputeConsentUseCase) private var fetchPrivateCloudComputeConsentUseCase
    @ObservationIgnored
    @Dependency(\.updatePrivateCloudComputeConsentUseCase) private var updatePrivateCloudComputeConsentUseCase
    @ObservationIgnored
    @Dependency(\.fetchAppVersionUseCase) private var fetchAppVersionUseCase
    @ObservationIgnored
    private var hasAttemptedPreparation = false
    /// 録音画面の表示中に Apple Watch から届いた録音。録音画面を閉じたら順に処理する。
    @ObservationIgnored
    private var pendingWatchRecordings: [URL] = []
    @ObservationIgnored
    private var isPreparing = false

    private func prepareForRecording() {
        guard !isPreparing, !isPreparedForRecording else { return }
        isPreparing = true
        Task {
            do {
                try await cleanUpTemporaryDataUseCase.execute()
                isPreparedForRecording = true
                syncWatchRecordingAvailability()
            } catch {
                alert = .preparationFailed
            }
            isPreparing = false
        }
    }

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            if availability == nil {
                availability = checkDeviceAvailabilityUseCase.execute()
            }
            guard !hasAttemptedPreparation else { return }
            hasAttemptedPreparation = true
            prepareForRecording()
            Task { await presentVoiceEnrollmentIfNeeded() }
            observePersonSearchNotificationTaps()
            startWatchSync()
        case .preparationRetryButtonTapped:
            alert = nil
            prepareForRecording()
        case .recordButtonTapped:
            guard availability?.isAvailable == true, isPreparedForRecording, !isRequestingPermission else { return }
            isRecordingSourceSelectionPresented = true
        case let .recordingSourceSelectionChanged(isPresented):
            isRecordingSourceSelectionPresented = isPresented
        case .chooseAudioFileTapped:
            isRecordingSourceSelectionPresented = false
            isFileImporterPresented = true
        case let .fileImporterPresentedChanged(isPresented):
            isFileImporterPresented = isPresented
        case let .audioFileSelected(url):
            isFileImporterPresented = false
            importedFileURL = url
            isRecordingPresented = true
        case .recordFromMicrophoneTapped:
            isRecordingSourceSelectionPresented = false
            guard availability?.isAvailable == true, isPreparedForRecording, !isRequestingPermission else { return }
            importedFileURL = nil
            isRequestingPermission = true
            Task {
                let permission = await requestRecordingPermissionUseCase.execute()
                isRequestingPermission = false
                if permission == .granted {
                    isRecordingPresented = true
                } else {
                    alert = .microphoneDenied
                }
            }
        case .settingsButtonTapped:
            alert = nil
            // 開けなくてもユーザーは設定アプリから手動で許可できるため、失敗は無視する
            Task { try? await openAppSettingsUseCase.execute() }
        case .alertDismissed:
            alert = nil
        case let .recordingFinished(profileID):
            isRecordingPresented = false
            importedFileURL = nil
            if let profileID { registeredProfileID = profileID }
            Task { await watchSyncService.syncProfiles() }
            presentNextWatchRecording()
        case .voiceEnrollmentCompleted:
            isVoiceEnrollmentPresented = false
            syncWatchRecordingAvailability()
        case .settingsMenuButtonTapped:
            isSettingsPresented = true
        case let .settingsPresentedChanged(isPresented):
            isSettingsPresented = isPresented
        case .personSearchNotificationTapped:
            // 候補一覧は録音画面の上の処理状況画面に表示されている。上に重なったシートを閉じてそれを見せる。
            // 録音画面を閉じた後のタップでは、ルートのプロフィール一覧に戻る
            isSettingsPresented = false
        case let .watchRecordingReceived(url):
            pendingWatchRecordings.append(url)
            presentNextWatchRecording()
        }
    }

    /// Apple Watch の録音は、ファイルアプリで選んだ音声ファイルと同じように取り込んで処理する。
    private func presentNextWatchRecording() {
        guard !isRecordingPresented, !isVoiceEnrollmentPresented,
              availability?.isAvailable == true, isPreparedForRecording,
              !pendingWatchRecordings.isEmpty
        else { return }
        isSettingsPresented = false
        importedFileURL = pendingWatchRecordings.removeFirst()
        isRecordingPresented = true
    }

    private func startWatchSync() {
        watchSyncService.activate()
        syncWatchRecordingAvailability()
        Task { await watchSyncService.syncProfiles() }
        Task { await syncWatchSettings() }
        let recordings = watchSyncService.recordings()
        Task { [weak self] in
            for await recording in recordings {
                guard let self else { return }
                switch recording.kind {
                case .conversation:
                    self.send(.watchRecordingReceived(recording.fileURL))
                case .selfVoice:
                    await self.registerSelfVoice(recording.fileURL)
                case .additional:
                    // 追加録音は処理状況画面が受け取る
                    break
                }
            }
        }
        let commands = watchSyncService.commands()
        Task { [weak self] in
            for await command in commands {
                guard let self else { return }
                switch command {
                case .requestSnapshot:
                    self.syncWatchRecordingAvailability()
                    await self.watchSyncService.syncProfiles()
                    await self.syncWatchSettings()
                case let .setPrivateCloudComputeEnabled(isEnabled):
                    self.updatePrivateCloudComputeConsentUseCase.execute(isEnabled ? .granted : .denied)
                    await self.syncWatchSettings()
                default:
                    // 処理中の録音への操作は処理状況画面が受け取る
                    break
                }
            }
        }
    }

    /// Apple Watch で録音した本人の声を登録する。登録画面を表示していれば、完了したら閉じる。
    private func registerSelfVoice(_ url: URL) async {
        watchSyncService.updateSettings { $0.selfVoiceEnrollment = .processing }
        do {
            try await registerSelfVoiceUseCase.execute(.file(url))
            watchSyncService.updateSettings { $0.selfVoiceEnrollment = .completed }
            if isVoiceEnrollmentPresented { send(.voiceEnrollmentCompleted) }
        } catch let SelfVoiceRegistrationError.insufficientSpeech(duration) {
            let message = String(localized: "声が足りませんでした (\(Int(duration)) 秒)。もう少し長く話して録音し直してください。")
            watchSyncService.updateSettings { $0.selfVoiceEnrollment = .failed(message: message) }
        } catch {
            watchSyncService.updateSettings { $0.selfVoiceEnrollment = .failed(message: String(localized: "登録できませんでした。もう一度お試しください。")) }
        }
        await syncWatchSettings()
    }

    private func syncWatchSettings() async {
        // 読み込めなくても未登録として表示するだけで、Apple Watch から登録し直せる
        let registeredAt = try? await fetchSelfVoiceUseCase.execute()?.createdAt
        let isPrivateCloudComputeEnabled = fetchPrivateCloudComputeConsentUseCase.execute() == .granted
        let version = fetchAppVersionUseCase.execute()
        let appVersion = "\(version.version) (\(version.build))"
        watchSyncService.updateSettings {
            $0.selfVoiceRegisteredAt = registeredAt
            $0.isPrivateCloudComputeEnabled = isPrivateCloudComputeEnabled
            $0.appVersion = appVersion
        }
    }

    private func syncWatchRecordingAvailability() {
        let isAvailable = availability?.isAvailable == true && isPreparedForRecording && !isVoiceEnrollmentPresented
        watchSyncService.updateRecordingAvailability(isAvailable)
        presentNextWatchRecording()
    }

    private func observePersonSearchNotificationTaps() {
        let taps = observePersonSearchNotificationTapUseCase.execute()
        Task { [weak self] in
            for await _ in taps {
                self?.send(.personSearchNotificationTapped)
            }
        }
    }

    /// 本人の声が未登録なら、利用開始前に登録画面を表示する。
    private func presentVoiceEnrollmentIfNeeded() async {
        // 読み込みに失敗してもユーザーにできることがないため、登録画面は出さずに続行する。
        guard let isRegistered = try? await fetchSelfVoiceRegisteredUseCase.execute() else { return }
        isVoiceEnrollmentPresented = !isRegistered
        syncWatchRecordingAvailability()
    }
}

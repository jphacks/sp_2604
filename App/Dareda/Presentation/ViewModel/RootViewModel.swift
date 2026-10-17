import Foundation
import Dependencies
import Observation

@Observable
final class RootViewModel {
    enum Action {
        case onAppear
        case recheckButtonTapped
        case recordButtonTapped
        case settingsButtonTapped
        case privateCloudComputeSettingsButtonTapped
        case privateCloudComputeSettingsPresentedChanged(Bool)
        case settingsMenuButtonTapped
        case settingsPresentedChanged(Bool)
        /// 新規登録で保存した場合はそのプロフィールの ID を持つ。
        case recordingFinished(Profile.ID?)
        case preparationRetryButtonTapped
        case voiceEnrollmentCompleted
        case personSearchNotificationTapped
    }

    private(set) var recordingPermission: RecordingPermission?
    private(set) var isRequestingPermission = false
    private(set) var settingsErrorMessage: String?

    private(set) var availability: DeviceAvailability?
    private(set) var isPrivateCloudComputeSettingsPresented = false
    private(set) var isSettingsPresented = false
    private(set) var isRecordingPresented = false
    private(set) var isPreparedForRecording = false
    private(set) var preparationErrorMessage: LocalizedStringResource?
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
    private var hasAttemptedPreparation = false
    @ObservationIgnored
    private var isPreparing = false

    private func prepareForRecording() {
        guard !isPreparing, !isPreparedForRecording else { return }
        isPreparing = true
        preparationErrorMessage = nil
        Task {
            do {
                try await cleanUpTemporaryDataUseCase.execute()
                isPreparedForRecording = true
            } catch {
                preparationErrorMessage = "前回の録音を整理できませんでした。再試行してください。"
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
        case .preparationRetryButtonTapped:
            prepareForRecording()
        case .recheckButtonTapped:
            availability = checkDeviceAvailabilityUseCase.execute()
        case .recordButtonTapped:
            guard availability?.isAvailable == true, isPreparedForRecording, !isRequestingPermission else { return }
            isRequestingPermission = true
            settingsErrorMessage = nil
            Task {
                recordingPermission = await requestRecordingPermissionUseCase.execute()
                isRequestingPermission = false
                isRecordingPresented = recordingPermission == .granted
            }
        case .settingsButtonTapped:
            Task {
                do {
                    try await openAppSettingsUseCase.execute()
                    settingsErrorMessage = nil
                } catch {
                    settingsErrorMessage = "設定アプリを開けませんでした。設定アプリからDaredaのマイクを許可してください。"
                }
            }
        case let .recordingFinished(profileID):
            isRecordingPresented = false
            if let profileID { registeredProfileID = profileID }
        case .voiceEnrollmentCompleted:
            isVoiceEnrollmentPresented = false
        case .privateCloudComputeSettingsButtonTapped:
            isPrivateCloudComputeSettingsPresented = true
        case let .privateCloudComputeSettingsPresentedChanged(isPresented):
            isPrivateCloudComputeSettingsPresented = isPresented
        case .settingsMenuButtonTapped:
            isSettingsPresented = true
        case let .settingsPresentedChanged(isPresented):
            isSettingsPresented = isPresented
        case .personSearchNotificationTapped:
            // 候補一覧は録音画面の上の処理状況画面に表示されている。上に重なったシートを閉じてそれを見せる。
            // 録音画面を閉じた後のタップでは、ルートのプロフィール一覧に戻る
            isPrivateCloudComputeSettingsPresented = false
            isSettingsPresented = false
        }
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
    }
}

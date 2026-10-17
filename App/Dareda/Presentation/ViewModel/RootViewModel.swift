import Foundation
import Dependencies
import Observation

@Observable
final class RootViewModel {
    enum Action {
        case onAppear
        case recordButtonTapped
        case settingsButtonTapped
        case alertDismissed
        case settingsMenuButtonTapped
        case settingsPresentedChanged(Bool)
        /// 新規登録で保存した場合はそのプロフィールの ID を持つ。
        case recordingFinished(Profile.ID?)
        case preparationRetryButtonTapped
        case voiceEnrollmentCompleted
        case personSearchNotificationTapped
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
    private var hasAttemptedPreparation = false
    @ObservationIgnored
    private var isPreparing = false

    private func prepareForRecording() {
        guard !isPreparing, !isPreparedForRecording else { return }
        isPreparing = true
        Task {
            do {
                try await cleanUpTemporaryDataUseCase.execute()
                isPreparedForRecording = true
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
        case .preparationRetryButtonTapped:
            alert = nil
            prepareForRecording()
        case .recordButtonTapped:
            guard availability?.isAvailable == true, isPreparedForRecording, !isRequestingPermission else { return }
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
            if let profileID { registeredProfileID = profileID }
        case .voiceEnrollmentCompleted:
            isVoiceEnrollmentPresented = false
        case .settingsMenuButtonTapped:
            isSettingsPresented = true
        case let .settingsPresentedChanged(isPresented):
            isSettingsPresented = isPresented
        case .personSearchNotificationTapped:
            // 候補一覧は録音画面の上の処理状況画面に表示されている。上に重なったシートを閉じてそれを見せる。
            // 録音画面を閉じた後のタップでは、ルートのプロフィール一覧に戻る
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

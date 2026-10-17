import Dependencies
import Foundation
import Observation

@Observable
final class SettingsViewModel {
    enum Action {
        case onAppear
        case reregisterVoiceButtonTapped
        case voiceReregistrationFinished
        case isPrivateCloudComputeEnabledChanged(Bool)
        /// 設定アプリから戻ったときなど、権限が変わった可能性があるときに読み直す。
        case sceneBecameActive
        case permissionRowTapped
    }

    private(set) var selfVoiceRegisteredAt: Date?
    private(set) var isVoiceReregistrationPresented = false
    private(set) var privateCloudComputeConsent: PrivateCloudComputeConsent = .undetermined
    private(set) var recordingPermission: RecordingPermission?
    private(set) var notificationPermission: NotificationPermission?
    private(set) var appVersion: AppVersion?

    @ObservationIgnored
    @Dependency(\.fetchSelfVoiceUseCase) private var fetchSelfVoiceUseCase
    @ObservationIgnored
    @Dependency(\.fetchPrivateCloudComputeConsentUseCase) private var fetchPrivateCloudComputeConsentUseCase
    @ObservationIgnored
    @Dependency(\.updatePrivateCloudComputeConsentUseCase) private var updatePrivateCloudComputeConsentUseCase
    @ObservationIgnored
    @Dependency(\.fetchRecordingPermissionUseCase) private var fetchRecordingPermissionUseCase
    @ObservationIgnored
    @Dependency(\.fetchNotificationPermissionUseCase) private var fetchNotificationPermissionUseCase
    @ObservationIgnored
    @Dependency(\.openAppSettingsUseCase) private var openAppSettingsUseCase
    @ObservationIgnored
    @Dependency(\.fetchAppVersionUseCase) private var fetchAppVersionUseCase

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            privateCloudComputeConsent = fetchPrivateCloudComputeConsentUseCase.execute()
            appVersion = fetchAppVersionUseCase.execute()
            Task { await fetch() }
            Task { await fetchPermissions() }
        case .reregisterVoiceButtonTapped:
            isVoiceReregistrationPresented = true
        case .voiceReregistrationFinished:
            isVoiceReregistrationPresented = false
            Task { await fetch() }
        case let .isPrivateCloudComputeEnabledChanged(isEnabled):
            privateCloudComputeConsent = isEnabled ? .granted : .denied
            updatePrivateCloudComputeConsentUseCase.execute(privateCloudComputeConsent)
        case .sceneBecameActive:
            Task { await fetchPermissions() }
        case .permissionRowTapped:
            // 開けなくてもユーザーは設定アプリから手動で変更できるため、失敗は無視する
            Task { try? await openAppSettingsUseCase.execute() }
        }
    }

    private func fetchPermissions() async {
        recordingPermission = fetchRecordingPermissionUseCase.execute()
        notificationPermission = await fetchNotificationPermissionUseCase.execute()
    }

    private func fetch() async {
        // 読み込みに失敗してもユーザーにできることがないため、登録日時を表示しないだけにする。
        selfVoiceRegisteredAt = try? await fetchSelfVoiceUseCase.execute()?.createdAt
    }
}

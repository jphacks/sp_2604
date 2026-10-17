import Dependencies
import Observation

@Observable
final class RootViewModel {
    enum Action {
        case onAppear
        case recheckButtonTapped
        case recordButtonTapped
        case settingsButtonTapped
        case profilesButtonTapped
        case profileListPresentedChanged(Bool)
    }

    private(set) var recordingPermission: RecordingPermission?
    private(set) var isRequestingPermission = false
    private(set) var settingsErrorMessage: String?

    private(set) var availability: DeviceAvailability?
    private(set) var isProfileListPresented = false

    @ObservationIgnored
    @Dependency(\.cleanUpTemporaryDataUseCase) private var cleanUpTemporaryDataUseCase
    @ObservationIgnored
    @Dependency(\.checkDeviceAvailabilityUseCase) private var checkDeviceAvailabilityUseCase
    @ObservationIgnored
    @Dependency(\.requestRecordingPermissionUseCase) private var requestRecordingPermissionUseCase
    @ObservationIgnored
    @Dependency(\.openAppSettingsUseCase) private var openAppSettingsUseCase
    @ObservationIgnored
    private var hasCleanedUp = false

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            if availability == nil {
                availability = checkDeviceAvailabilityUseCase.execute()
            }
            // 起動ごとに 1 回だけ実行する。失敗してもユーザーにできることはないため状態は持たない。
            guard !hasCleanedUp else { return }
            hasCleanedUp = true
            Task { try? await cleanUpTemporaryDataUseCase.execute() }
        case .recheckButtonTapped:
            availability = checkDeviceAvailabilityUseCase.execute()
        case .recordButtonTapped:
            guard availability?.isAvailable == true, !isRequestingPermission else { return }
            isRequestingPermission = true
            settingsErrorMessage = nil
            Task {
                recordingPermission = await requestRecordingPermissionUseCase.execute()
                isRequestingPermission = false
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
        case .profilesButtonTapped:
            isProfileListPresented = true
        case let .profileListPresentedChanged(isPresented):
            isProfileListPresented = isPresented
        }
    }
}

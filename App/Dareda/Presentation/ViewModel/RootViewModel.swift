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
        case profilesButtonTapped
        case profileListPresentedChanged(Bool)
        case recordingFinished
        case preparationRetryButtonTapped
    }

    private(set) var recordingPermission: RecordingPermission?
    private(set) var isRequestingPermission = false
    private(set) var settingsErrorMessage: String?

    private(set) var availability: DeviceAvailability?
    private(set) var isProfileListPresented = false
    private(set) var isRecordingPresented = false
    private(set) var isPreparedForRecording = false
    private(set) var preparationErrorMessage: LocalizedStringResource?

    @ObservationIgnored
    @Dependency(\.cleanUpTemporaryDataUseCase) private var cleanUpTemporaryDataUseCase
    @ObservationIgnored
    @Dependency(\.checkDeviceAvailabilityUseCase) private var checkDeviceAvailabilityUseCase
    @ObservationIgnored
    @Dependency(\.requestRecordingPermissionUseCase) private var requestRecordingPermissionUseCase
    @ObservationIgnored
    @Dependency(\.openAppSettingsUseCase) private var openAppSettingsUseCase
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
        case .recordingFinished:
            isRecordingPresented = false
        case .profilesButtonTapped:
            isProfileListPresented = true
        case let .profileListPresentedChanged(isPresented):
            isProfileListPresented = isPresented
        }
    }
}

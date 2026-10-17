import Dependencies
import Observation

@Observable
final class PrivateCloudComputeSettingsViewModel {
    enum Action {
        case onAppear
        case isEnabledChanged(Bool)
    }

    private(set) var consent: PrivateCloudComputeConsent = .undetermined

    @ObservationIgnored
    @Dependency(\.fetchPrivateCloudComputeConsentUseCase) private var fetchPrivateCloudComputeConsentUseCase
    @ObservationIgnored
    @Dependency(\.updatePrivateCloudComputeConsentUseCase) private var updatePrivateCloudComputeConsentUseCase

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            consent = fetchPrivateCloudComputeConsentUseCase.execute()
        case let .isEnabledChanged(isEnabled):
            consent = isEnabled ? .granted : .denied
            updatePrivateCloudComputeConsentUseCase.execute(consent)
        }
    }
}

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
    }

    private(set) var selfVoiceRegisteredAt: Date?
    private(set) var isVoiceReregistrationPresented = false
    private(set) var privateCloudComputeConsent: PrivateCloudComputeConsent = .undetermined

    @ObservationIgnored
    @Dependency(\.fetchSelfVoiceUseCase) private var fetchSelfVoiceUseCase
    @ObservationIgnored
    @Dependency(\.fetchPrivateCloudComputeConsentUseCase) private var fetchPrivateCloudComputeConsentUseCase
    @ObservationIgnored
    @Dependency(\.updatePrivateCloudComputeConsentUseCase) private var updatePrivateCloudComputeConsentUseCase

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            privateCloudComputeConsent = fetchPrivateCloudComputeConsentUseCase.execute()
            Task { await fetch() }
        case .reregisterVoiceButtonTapped:
            isVoiceReregistrationPresented = true
        case .voiceReregistrationFinished:
            isVoiceReregistrationPresented = false
            Task { await fetch() }
        case let .isPrivateCloudComputeEnabledChanged(isEnabled):
            privateCloudComputeConsent = isEnabled ? .granted : .denied
            updatePrivateCloudComputeConsentUseCase.execute(privateCloudComputeConsent)
        }
    }

    private func fetch() async {
        // 読み込みに失敗してもユーザーにできることがないため、登録日時を表示しないだけにする。
        selfVoiceRegisteredAt = try? await fetchSelfVoiceUseCase.execute()?.createdAt
    }
}

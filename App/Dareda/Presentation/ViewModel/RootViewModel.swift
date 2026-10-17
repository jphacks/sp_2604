import Dependencies
import Observation

@Observable
final class RootViewModel {
    enum Action {
        case onAppear
        case recheckButtonTapped
        case profilesButtonTapped
        case profileListPresentedChanged(Bool)
        case voiceEnrollmentCompleted
    }

    private(set) var availability: DeviceAvailability?
    private(set) var isProfileListPresented = false
    private(set) var isVoiceEnrollmentPresented = false

    @ObservationIgnored
    @Dependency(\.cleanUpTemporaryDataUseCase) private var cleanUpTemporaryDataUseCase
    @ObservationIgnored
    @Dependency(\.checkDeviceAvailabilityUseCase) private var checkDeviceAvailabilityUseCase
    @ObservationIgnored
    @Dependency(\.fetchSelfVoiceRegisteredUseCase) private var fetchSelfVoiceRegisteredUseCase
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
            Task { await presentVoiceEnrollmentIfNeeded() }
        case .recheckButtonTapped:
            availability = checkDeviceAvailabilityUseCase.execute()
        case .profilesButtonTapped:
            isProfileListPresented = true
        case let .profileListPresentedChanged(isPresented):
            isProfileListPresented = isPresented
        case .voiceEnrollmentCompleted:
            isVoiceEnrollmentPresented = false
        }
    }

    /// 本人の声が未登録なら、利用開始前に登録画面を表示する。
    private func presentVoiceEnrollmentIfNeeded() async {
        // 読み込みに失敗してもユーザーにできることがないため、登録画面は出さずに続行する。
        guard let isRegistered = try? await fetchSelfVoiceRegisteredUseCase.execute() else { return }
        isVoiceEnrollmentPresented = !isRegistered
    }
}

import Dependencies
import Observation

@Observable
final class RootViewModel {
    enum Action {
        case onAppear
        case recheckButtonTapped
        case profilesButtonTapped
        case profileListPresentedChanged(Bool)
    }

    private(set) var availability: DeviceAvailability?
    private(set) var isProfileListPresented = false

    @ObservationIgnored
    @Dependency(\.cleanUpTemporaryDataUseCase) private var cleanUpTemporaryDataUseCase
    @ObservationIgnored
    @Dependency(\.checkDeviceAvailabilityUseCase) private var checkDeviceAvailabilityUseCase
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
        case .profilesButtonTapped:
            isProfileListPresented = true
        case let .profileListPresentedChanged(isPresented):
            isProfileListPresented = isPresented
        }
    }
}

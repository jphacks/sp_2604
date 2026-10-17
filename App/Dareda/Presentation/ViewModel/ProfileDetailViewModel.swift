import Dependencies
import Observation

@Observable
final class ProfileDetailViewModel {
    enum Action {
        case onAppear
    }

    let profileID: Profile.ID
    private(set) var detail: ProfileDetailServiceModel?

    @ObservationIgnored
    @Dependency(\.fetchProfileDetailUseCase) private var fetchProfileDetailUseCase

    init(profileID: Profile.ID) {
        self.profileID = profileID
    }

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            Task { await fetch() }
        }
    }

    private func fetch() async {
        // 読み込みに失敗してもユーザーにできることがないため、何も表示しない。
        detail = try? await fetchProfileDetailUseCase.execute(profileID)
    }
}

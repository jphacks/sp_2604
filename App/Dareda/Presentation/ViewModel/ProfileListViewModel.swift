import Dependencies
import Observation

@Observable
final class ProfileListViewModel {
    enum Action {
        case onAppear
        case pathChanged([Profile.ID])
    }

    private(set) var profiles: [Profile] = []
    private(set) var path: [Profile.ID] = []

    @ObservationIgnored
    @Dependency(\.fetchProfilesUseCase) private var fetchProfilesUseCase

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            Task { await fetch() }
        case let .pathChanged(path):
            self.path = path
        }
    }

    private func fetch() async {
        // 読み込みに失敗してもユーザーにできることがないため、表示中の一覧を維持する。
        guard let profiles = try? await fetchProfilesUseCase.execute() else { return }
        self.profiles = profiles
    }
}

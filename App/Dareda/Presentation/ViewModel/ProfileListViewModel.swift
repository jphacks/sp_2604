import Dependencies
import Observation

@Observable
final class ProfileListViewModel {
    enum Action {
        case onAppear
        case pathChanged([Profile.ID])
        case profileRegistered(Profile.ID)
        case profileUpdated
        case profileDeleted
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
        case let .profileRegistered(id):
            path = [id]
            Task { await fetch() }
        case .profileUpdated:
            Task { await fetch() }
        case .profileDeleted:
            path = []
            Task { await fetch() }
        }
    }

    private func fetch() async {
        // 読み込みに失敗してもユーザーにできることがないため、表示中の一覧を維持する。
        guard let profiles = try? await fetchProfilesUseCase.execute() else { return }
        self.profiles = profiles
    }
}

import Dependencies
import Observation

@Observable
final class RootViewModel {
    enum Action {
        case onAppear
    }

    @ObservationIgnored
    @Dependency(\.cleanUpTemporaryDataUseCase) private var cleanUpTemporaryDataUseCase
    @ObservationIgnored
    private var hasCleanedUp = false

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            // 起動ごとに 1 回だけ実行する。失敗してもユーザーにできることはないため状態は持たない。
            guard !hasCleanedUp else { return }
            hasCleanedUp = true
            Task { try? await cleanUpTemporaryDataUseCase.execute() }
        }
    }
}

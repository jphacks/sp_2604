import Dependencies
import Foundation
import Observation

@Observable
final class PlaceSearchViewModel {
    enum Action {
        case queryChanged(String)
    }

    private(set) var query = ""
    private(set) var places: [Place] = []

    @ObservationIgnored
    @Dependency(\.searchPlacesUseCase) private var searchPlacesUseCase
    @ObservationIgnored
    @Dependency(\.continuousClock) private var clock
    @ObservationIgnored
    private var searchTask: Task<Void, Never>?

    func send(_ action: Action) {
        switch action {
        case let .queryChanged(query):
            self.query = query
            searchTask?.cancel()
            searchTask = Task { await search(query) }
        }
    }

    private func search(_ query: String) async {
        // 入力のたびに検索しないよう、入力が止まるまで待つ。
        do {
            try await clock.sleep(for: .milliseconds(300))
        } catch {
            return
        }
        // 失敗してもユーザーは入力し直す以外にできることがないため、エラー状態は持たず候補を空にする。
        let places = (try? await searchPlacesUseCase.execute(query)) ?? []
        guard !Task.isCancelled else { return }
        self.places = places
    }
}

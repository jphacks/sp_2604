import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct SearchPlacesUseCase: Sendable {
    var execute: @Sendable (_ query: String) async throws -> [Place]
}

nonisolated extension SearchPlacesUseCase: DependencyKey {
    static let liveValue: SearchPlacesUseCase = {
        let impl = SearchPlacesUseCaseImpl()
        return SearchPlacesUseCase(
            execute: impl.execute(_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var searchPlacesUseCase: SearchPlacesUseCase {
        get { self[SearchPlacesUseCase.self] }
        set { self[SearchPlacesUseCase.self] = newValue }
    }
}

private nonisolated struct SearchPlacesUseCaseImpl: Sendable {
    @Dependency(\.placeSearchGateway) private var placeSearchGateway

    func execute(_ query: String) async throws -> [Place] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return try await placeSearchGateway.search(query)
    }
}

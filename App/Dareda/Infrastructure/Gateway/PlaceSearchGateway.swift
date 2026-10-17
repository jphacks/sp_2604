import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct PlaceSearchGateway: Sendable {
    /// クエリに一致する場所の候補を返す。名前の無い地点は選択肢として扱えないため除く。
    var search: @Sendable (_ query: String) async throws -> [Place]
}

nonisolated extension PlaceSearchGateway: DependencyKey {
    static let liveValue: PlaceSearchGateway = {
        let impl = PlaceSearchGatewayImpl()
        return PlaceSearchGateway(
            search: impl.search(_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var placeSearchGateway: PlaceSearchGateway {
        get { self[PlaceSearchGateway.self] }
        set { self[PlaceSearchGateway.self] = newValue }
    }
}

private nonisolated struct PlaceSearchGatewayImpl: Sendable {
    @Dependency(\.mapKitClient) private var mapKitClient

    func search(_ query: String) async throws -> [Place] {
        try await mapKitClient.searchPlaces(query).compactMap { item in
            guard let name = item.name, !name.isEmpty else { return nil }
            return Place(name: name, latitude: item.latitude, longitude: item.longitude)
        }
    }
}

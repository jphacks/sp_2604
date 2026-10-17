import Dependencies
import DependenciesMacros
import MapKit

@DependencyClient
nonisolated struct MapKitClient: Sendable {
    /// 自然言語のクエリで地点を検索し、(名前, 緯度, 経度) を検索結果の順に返す。
    var searchPlaces: @Sendable (_ query: String) async throws -> [(name: String?, latitude: Double, longitude: Double)]
}

nonisolated extension MapKitClient: DependencyKey {
    static let liveValue: MapKitClient = {
        let impl = MapKitClientImpl()
        return MapKitClient(
            searchPlaces: impl.searchPlaces(query:)
        )
    }()

    static let testValue = MapKitClient.inMemory()
    static let previewValue = MapKitClient.inMemory()
}

nonisolated extension DependencyValues {
    var mapKitClient: MapKitClient {
        get { self[MapKitClient.self] }
        set { self[MapKitClient.self] = newValue }
    }
}

private nonisolated struct MapKitClientImpl: Sendable {
    func searchPlaces(query: String) async throws -> [(name: String?, latitude: Double, longitude: Double)] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.map { item in
            let coordinate = item.location.coordinate
            return (name: item.name, latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }
}

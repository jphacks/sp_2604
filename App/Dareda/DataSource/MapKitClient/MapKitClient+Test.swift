import Foundation

nonisolated extension MapKitClient {
    /// MapKit を使わないテストダブル。名前にクエリを含む地点だけを返す。
    static func inMemory(
        places: [(name: String?, latitude: Double, longitude: Double)] = [
            (name: "札幌駅", latitude: 43.0687, longitude: 141.3508),
            (name: "北海道大学", latitude: 43.0742, longitude: 141.3405),
            (name: "大通公園", latitude: 43.0598, longitude: 141.3474),
        ]
    ) -> MapKitClient {
        MapKitClient(searchPlaces: { query in
            places.filter { $0.name?.localizedStandardContains(query) ?? false }
        })
    }
}

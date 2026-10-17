import Dependencies
import DependenciesMacros
import Foundation

/// 出会い記録の保存は `ProfileRepository.add` で行う (プロフィールと同時に保存するため)。
/// 再会時に既存記録を追加・変更しない前提のため、ここには参照 API だけを置く。
@DependencyClient
nonisolated struct EncounterRepository: Sendable {
    /// プロフィールの初回の出会い記録を返す。
    var get: @Sendable (_ profileID: Profile.ID) async throws -> Encounter?
}

nonisolated extension EncounterRepository: DependencyKey {
    static let liveValue: EncounterRepository = {
        let impl = EncounterRepositoryImpl()
        return EncounterRepository(
            get: impl.get(profileID:)
        )
    }()
}

nonisolated extension DependencyValues {
    var encounterRepository: EncounterRepository {
        get { self[EncounterRepository.self] }
        set { self[EncounterRepository.self] = newValue }
    }
}

private nonisolated struct EncounterRepositoryImpl: Sendable {
    @Dependency(\.sqliteDataClient) private var sqliteDataClient

    func get(profileID: Profile.ID) async throws -> Encounter? {
        try await sqliteDataClient.encounter(profileID).map(Encounter.init(record:))
    }
}

nonisolated extension EncounterRecord {
    /// `ProfileRepository` からも使う。
    init(encounter: Encounter) {
        self.init(
            id: encounter.id,
            profileID: encounter.profileID,
            summary: encounter.summary,
            metAt: encounter.metAt,
            placeName: encounter.place?.name,
            latitude: encounter.place?.latitude,
            longitude: encounter.place?.longitude
        )
    }
}

private nonisolated extension Encounter {
    init(record: EncounterRecord) {
        let place: Place?
        if let name = record.placeName, let latitude = record.latitude, let longitude = record.longitude {
            place = Place(name: name, latitude: latitude, longitude: longitude)
        } else {
            place = nil
        }
        self.init(
            id: record.id,
            profileID: record.profileID,
            summary: record.summary,
            metAt: record.metAt,
            place: place
        )
    }
}

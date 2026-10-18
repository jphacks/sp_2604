import Dependencies
import DependenciesMacros
import Foundation

/// 更新できるのは名前・所属・前回の会話の記録。声の特徴ベクトルは登録時の値を保つ。
@DependencyClient
nonisolated struct ProfileRepository: Sendable {
    /// 名前順で全件を返す。
    var getAll: @Sendable () async throws -> [Profile]
    var get: @Sendable (_ id: Profile.ID) async throws -> Profile?
    /// 新規登録。プロフィールと前回の会話の記録を同時に保存する (どちらかが失敗した場合は両方保存しない)。
    var add: @Sendable (_ profile: Profile, _ firstEncounter: Encounter) async throws -> Void
    /// 名前・所属を更新し、前回の会話の記録を置き換える (どちらかが失敗した場合は両方更新しない)。
    var update: @Sendable (
        _ id: Profile.ID, _ name: String, _ affiliation: String, _ encounter: Encounter
    ) async throws -> Void
    /// プロフィールと、それに紐づく出会い記録を削除する。
    var delete: @Sendable (_ id: Profile.ID) async throws -> Void
}

nonisolated extension ProfileRepository: DependencyKey {
    static let liveValue: ProfileRepository = {
        let impl = ProfileRepositoryImpl()
        return ProfileRepository(
            getAll: impl.getAll,
            get: impl.get(id:),
            add: impl.add(_:firstEncounter:),
            update: impl.update(id:name:affiliation:encounter:),
            delete: impl.delete(id:)
        )
    }()
}

nonisolated extension DependencyValues {
    var profileRepository: ProfileRepository {
        get { self[ProfileRepository.self] }
        set { self[ProfileRepository.self] = newValue }
    }
}

private nonisolated struct ProfileRepositoryImpl: Sendable {
    @Dependency(\.sqliteDataClient) private var sqliteDataClient

    func getAll() async throws -> [Profile] {
        try await sqliteDataClient.profiles().map(Profile.init(record:))
    }

    func get(id: Profile.ID) async throws -> Profile? {
        try await sqliteDataClient.profile(id).map(Profile.init(record:))
    }

    func add(_ profile: Profile, firstEncounter: Encounter) async throws {
        let profileRecord = ProfileRecord(
            id: profile.id,
            name: profile.name,
            affiliation: profile.affiliation,
            vector: Data(vector: profile.vector)
        )
        try await sqliteDataClient.insertProfile(
            profileRecord,
            EncounterRecord(encounter: firstEncounter)
        )
    }

    func update(id: Profile.ID, name: String, affiliation: String, encounter: Encounter) async throws {
        try await sqliteDataClient.updateProfile(id, name, affiliation, EncounterRecord(encounter: encounter))
    }

    func delete(id: Profile.ID) async throws {
        try await sqliteDataClient.deleteProfile(id)
    }
}

private nonisolated extension Profile {
    init(record: ProfileRecord) throws {
        self.init(
            id: record.id,
            name: record.name,
            affiliation: record.affiliation,
            vector: try record.vector.vector()
        )
    }
}

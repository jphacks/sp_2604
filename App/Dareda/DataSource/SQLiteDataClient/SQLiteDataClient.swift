import Dependencies
import DependenciesMacros
import Foundation
import SQLiteData

// MARK: - Interface

@DependencyClient
nonisolated struct SQLiteDataClient: Sendable {
    var selfVoice: @Sendable () async throws -> SelfVoiceRecord?
    var setSelfVoice: @Sendable (_ record: SelfVoiceRecord) async throws -> Void
    var deleteSelfVoice: @Sendable () async throws -> Void

    var profiles: @Sendable () async throws -> [ProfileRecord]
    var profile: @Sendable (_ id: UUID) async throws -> ProfileRecord?
    /// プロフィールと初回の出会い記録を 1 つのトランザクションで追加する。
    var insertProfile: @Sendable (_ profile: ProfileRecord, _ encounter: EncounterRecord) async throws -> Void
    var deleteProfile: @Sendable (_ id: UUID) async throws -> Void

    var encounter: @Sendable (_ profileID: UUID) async throws -> EncounterRecord?
}

nonisolated extension SQLiteDataClient: DependencyKey {
    static let liveValue: SQLiteDataClient = {
        let impl = SQLiteDataClientImpl()
        return SQLiteDataClient(
            selfVoice: impl.selfVoice,
            setSelfVoice: impl.setSelfVoice(_:),
            deleteSelfVoice: impl.deleteSelfVoice,
            profiles: impl.profiles,
            profile: impl.profile(id:),
            insertProfile: impl.insertProfile(_:encounter:),
            deleteProfile: impl.deleteProfile(id:),
            encounter: impl.encounter(profileID:)
        )
    }()

    /// データベースは `defaultDatabase` 経由で差し替えるため、テスト・プレビューも同じ実装を使う。
    static var testValue: SQLiteDataClient { liveValue }
    static var previewValue: SQLiteDataClient { liveValue }
}

nonisolated extension DependencyValues {
    var sqliteDataClient: SQLiteDataClient {
        get { self[SQLiteDataClient.self] }
        set { self[SQLiteDataClient.self] = newValue }
    }
}

// MARK: - Tables

@Table("selfVoices")
nonisolated struct SelfVoiceRecord: Sendable, Equatable {
    /// 常に 1 (本人の識別用ベクトルは 1 件だけ保持する)。
    let id: Int
    var vector: Data
    var createdAt: Date

    static let singletonID = 1
}

@Table("profiles")
nonisolated struct ProfileRecord: Sendable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var affiliation: String
    var vector: Data
}

@Table("encounters")
nonisolated struct EncounterRecord: Sendable, Equatable, Identifiable {
    let id: UUID
    var profileID: UUID
    var summary: String
    var metAt: Date
    var placeName: String?
    var latitude: Double?
    var longitude: Double?
}

// MARK: - Impl

private nonisolated struct SQLiteDataClientImpl: Sendable {
    @Dependency(\.defaultDatabase) private var database

    func selfVoice() async throws -> SelfVoiceRecord? {
        try await database.read { db in
            try SelfVoiceRecord.find(SelfVoiceRecord.singletonID).fetchOne(db)
        }
    }

    func setSelfVoice(_ record: SelfVoiceRecord) async throws {
        try await database.write { db in
            try SelfVoiceRecord.find(SelfVoiceRecord.singletonID).delete().execute(db)
            try SelfVoiceRecord.insert { record }.execute(db)
        }
    }

    func deleteSelfVoice() async throws {
        try await database.write { db in
            try SelfVoiceRecord.delete().execute(db)
        }
    }

    func profiles() async throws -> [ProfileRecord] {
        try await database.read { db in
            try ProfileRecord.order(by: \.name).fetchAll(db)
        }
    }

    func profile(id: UUID) async throws -> ProfileRecord? {
        try await database.read { db in
            try ProfileRecord.find(id).fetchOne(db)
        }
    }

    func insertProfile(_ profile: ProfileRecord, encounter: EncounterRecord) async throws {
        try await database.write { db in
            try ProfileRecord.insert { profile }.execute(db)
            try EncounterRecord.insert { encounter }.execute(db)
        }
    }

    func deleteProfile(id: UUID) async throws {
        try await database.write { db in
            try ProfileRecord.find(id).delete().execute(db)
        }
    }

    func encounter(profileID: UUID) async throws -> EncounterRecord? {
        try await database.read { db in
            try EncounterRecord.where { $0.profileID.eq(profileID) }.fetchOne(db)
        }
    }
}

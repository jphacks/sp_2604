import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct SelfVoiceRepository: Sendable {
    var get: @Sendable () async throws -> SelfVoice?
    /// 本人の識別用ベクトルを保存する。既に保存済みの場合は置き換える (再登録)。
    var set: @Sendable (_ selfVoice: SelfVoice) async throws -> Void
    var delete: @Sendable () async throws -> Void
}

nonisolated extension SelfVoiceRepository: DependencyKey {
    static let liveValue: SelfVoiceRepository = {
        let impl = SelfVoiceRepositoryImpl()
        return SelfVoiceRepository(
            get: impl.get,
            set: impl.set(_:),
            delete: impl.delete
        )
    }()
}

nonisolated extension DependencyValues {
    var selfVoiceRepository: SelfVoiceRepository {
        get { self[SelfVoiceRepository.self] }
        set { self[SelfVoiceRepository.self] = newValue }
    }
}

private nonisolated struct SelfVoiceRepositoryImpl: Sendable {
    @Dependency(\.sqliteDataClient) private var sqliteDataClient

    func get() async throws -> SelfVoice? {
        guard let record = try await sqliteDataClient.selfVoice() else { return nil }
        return SelfVoice(vector: try record.vector.vector(), createdAt: record.createdAt)
    }

    func set(_ selfVoice: SelfVoice) async throws {
        let record = SelfVoiceRecord(
            id: SelfVoiceRecord.singletonID,
            vector: Data(vector: selfVoice.vector),
            createdAt: selfVoice.createdAt
        )
        try await sqliteDataClient.setSelfVoice(record)
    }

    func delete() async throws {
        try await sqliteDataClient.deleteSelfVoice()
    }
}

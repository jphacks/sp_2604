import Dependencies
import DependenciesMacros
import Foundation

/// 処理セッション単位の一時保存領域を管理する。
@DependencyClient
nonisolated struct ProcessingSessionRepository: Sendable {
    var create: @Sendable () async throws -> ProcessingSession
    var delete: @Sendable (_ session: ProcessingSession) async throws -> Void
    var deleteAll: @Sendable () async throws -> Void
}

nonisolated extension ProcessingSessionRepository: DependencyKey {
    static let liveValue: ProcessingSessionRepository = {
        let impl = ProcessingSessionRepositoryImpl()
        return ProcessingSessionRepository(
            create: impl.create,
            delete: impl.delete(_:),
            deleteAll: impl.deleteAll
        )
    }()
}

nonisolated extension DependencyValues {
    var processingSessionRepository: ProcessingSessionRepository {
        get { self[ProcessingSessionRepository.self] }
        set { self[ProcessingSessionRepository.self] = newValue }
    }
}

private nonisolated struct ProcessingSessionRepositoryImpl: Sendable {
    @Dependency(\.fileSystemClient) private var fileSystemClient
    @Dependency(\.uuid) private var uuid

    private var rootURL: URL {
        fileSystemClient.temporaryDirectory().appendingPathComponent("ProcessingSessions", isDirectory: true)
    }

    func create() async throws -> ProcessingSession {
        let id = uuid()
        let directoryURL = rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
        try fileSystemClient.createDirectory(directoryURL)
        return ProcessingSession(id: id, directoryURL: directoryURL)
    }

    func delete(_ session: ProcessingSession) async throws {
        guard fileSystemClient.fileExists(session.directoryURL) else { return }
        try fileSystemClient.removeItem(session.directoryURL)
    }

    func deleteAll() async throws {
        guard fileSystemClient.fileExists(rootURL) else { return }
        // 1 件の削除失敗で残りを止めないよう、最後にまとめてエラーを返す。
        var firstError: any Error?
        for url in try fileSystemClient.contentsOfDirectory(rootURL) {
            do {
                try fileSystemClient.removeItem(url)
            } catch {
                firstError = firstError ?? error
            }
        }
        if let firstError { throw firstError }
    }
}

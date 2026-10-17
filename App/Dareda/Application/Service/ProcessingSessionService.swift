import Dependencies
import DependenciesMacros

/// 処理セッションの一時データのライフサイクルを扱う。
///
/// 削除するのは次のタイミングのみ。通常のバックグラウンド移行や処理・保存の失敗時には呼ばない。
/// - 新規登録の保存成功
/// - 人物検索で既存人物の確認完了
/// - キャンセル確定
/// - 起動時 (前回終了時に残った全セッション)
@DependencyClient
nonisolated struct ProcessingSessionService: Sendable {
    var start: @Sendable () async throws -> ProcessingSession
    var discard: @Sendable (_ session: ProcessingSession) async throws -> Void
    var discardAll: @Sendable () async throws -> Void
}

nonisolated extension ProcessingSessionService: DependencyKey {
    static let liveValue: ProcessingSessionService = {
        let impl = ProcessingSessionServiceImpl()
        return ProcessingSessionService(
            start: impl.start,
            discard: impl.discard(_:),
            discardAll: impl.discardAll
        )
    }()
}

nonisolated extension DependencyValues {
    var processingSessionService: ProcessingSessionService {
        get { self[ProcessingSessionService.self] }
        set { self[ProcessingSessionService.self] = newValue }
    }
}

private nonisolated struct ProcessingSessionServiceImpl: Sendable {
    @Dependency(\.processingSessionRepository) private var processingSessionRepository

    func start() async throws -> ProcessingSession {
        try await processingSessionRepository.create()
    }

    func discard(_ session: ProcessingSession) async throws {
        try await processingSessionRepository.delete(session)
    }

    func discardAll() async throws {
        try await processingSessionRepository.deleteAll()
    }
}

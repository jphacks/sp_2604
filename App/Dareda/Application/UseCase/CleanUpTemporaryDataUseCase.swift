import Dependencies
import DependenciesMacros

/// 起動時に、前回終了時に残った一時データを削除する (Phase 1 は途中状態を復元しない)。
@DependencyClient
nonisolated struct CleanUpTemporaryDataUseCase: Sendable {
    var execute: @Sendable () async throws -> Void
}

nonisolated extension CleanUpTemporaryDataUseCase: DependencyKey {
    static let liveValue: CleanUpTemporaryDataUseCase = {
        let impl = CleanUpTemporaryDataUseCaseImpl()
        return CleanUpTemporaryDataUseCase(execute: impl.execute)
    }()
}

nonisolated extension DependencyValues {
    var cleanUpTemporaryDataUseCase: CleanUpTemporaryDataUseCase {
        get { self[CleanUpTemporaryDataUseCase.self] }
        set { self[CleanUpTemporaryDataUseCase.self] = newValue }
    }
}

private nonisolated struct CleanUpTemporaryDataUseCaseImpl: Sendable {
    @Dependency(\.processingSessionService) private var processingSessionService

    @Dependency(\.audioRecordingGateway) private var audioRecordingGateway

    func execute() async throws {
        try await processingSessionService.discardAll()
        try audioRecordingGateway.discardAll()
    }
}

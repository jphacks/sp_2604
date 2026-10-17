import Dependencies
import DependenciesMacros

/// 確認を経た処理・保存のキャンセルを確定し、録音と処理セッションの一時データを削除する。
@DependencyClient
nonisolated struct CancelProcessingUseCase: Sendable {
    /// まだ作られていないものは `nil` を渡す。
    var execute: @Sendable (_ recording: Recording?, _ session: ProcessingSession?) async throws -> Void
}

nonisolated extension CancelProcessingUseCase: DependencyKey {
    static let liveValue: CancelProcessingUseCase = {
        let impl = CancelProcessingUseCaseImpl()
        return CancelProcessingUseCase(
            execute: impl.execute(_:_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var cancelProcessingUseCase: CancelProcessingUseCase {
        get { self[CancelProcessingUseCase.self] }
        set { self[CancelProcessingUseCase.self] = newValue }
    }
}

private nonisolated struct CancelProcessingUseCaseImpl: Sendable {
    @Dependency(\.recordingService) private var recordingService
    @Dependency(\.processingSessionService) private var processingSessionService

    func execute(_ recording: Recording?, _ session: ProcessingSession?) async throws {
        if let recording { try recordingService.discard(recording) }
        if let session { try await processingSessionService.discard(session) }
    }
}

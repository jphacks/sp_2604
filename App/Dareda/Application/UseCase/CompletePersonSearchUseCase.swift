import Dependencies
import DependenciesMacros

/// 人物検索で既存の人物を確認し終えたときに、録音と処理セッションの一時データを削除する。
/// 既存のプロフィール・出会い記録・声のベクトルは変更しない。
@DependencyClient
nonisolated struct CompletePersonSearchUseCase: Sendable {
    var execute: @Sendable (_ recordings: [PersonSearchRecording]) async throws -> Void
}

nonisolated extension CompletePersonSearchUseCase: DependencyKey {
    static let liveValue: CompletePersonSearchUseCase = {
        let impl = CompletePersonSearchUseCaseImpl()
        return CompletePersonSearchUseCase(
            execute: impl.execute(_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var completePersonSearchUseCase: CompletePersonSearchUseCase {
        get { self[CompletePersonSearchUseCase.self] }
        set { self[CompletePersonSearchUseCase.self] = newValue }
    }
}

private nonisolated struct CompletePersonSearchUseCaseImpl: Sendable {
    @Dependency(\.recordingService) private var recordingService
    @Dependency(\.processingSessionService) private var processingSessionService

    func execute(_ recordings: [PersonSearchRecording]) async throws {
        for target in recordings {
            try recordingService.discard(target.recording)
            try await processingSessionService.discard(target.session)
        }
    }
}

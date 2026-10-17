import Dependencies
import DependenciesMacros
import Foundation

/// アプリがバックグラウンドに移行しても処理を続けるための実行時間の確保。
@DependencyClient
nonisolated struct BackgroundExecutionGateway: Sendable {
    /// 実行時間の確保を始める。OS が打ち切るときは `onExpiration` を呼ぶ (確保は自動で終了する)。
    var begin: @Sendable (
        _ onExpiration: @escaping @Sendable () -> Void
    ) async -> BackgroundExecution = { _ in BackgroundExecution(id: 0) }
    /// システムの UI に表示する処理状況を更新する。
    var update: @Sendable (_ execution: BackgroundExecution, _ stage: ConversationAnalysisStage) async -> Void
    var end: @Sendable (_ execution: BackgroundExecution) async -> Void
}

nonisolated extension BackgroundExecutionGateway: DependencyKey {
    static let liveValue: BackgroundExecutionGateway = {
        let impl = BackgroundExecutionGatewayImpl()
        return BackgroundExecutionGateway(
            begin: impl.begin(onExpiration:),
            update: impl.update(_:stage:),
            end: impl.end(_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var backgroundExecutionGateway: BackgroundExecutionGateway {
        get { self[BackgroundExecutionGateway.self] }
        set { self[BackgroundExecutionGateway.self] = newValue }
    }
}

private nonisolated struct BackgroundExecutionGatewayImpl: Sendable {
    @Dependency(\.backgroundTaskClient) private var backgroundTaskClient

    func begin(onExpiration: @escaping @Sendable () -> Void) async -> BackgroundExecution {
        let identifier = await backgroundTaskClient.begin("会話を処理しています", onExpiration)
        return BackgroundExecution(id: identifier)
    }

    /// 文字起こし・話者識別・要約の 3 段階のうち、完了した段階の数を進捗とする。
    func update(_ execution: BackgroundExecution, stage: ConversationAnalysisStage) async {
        let completedUnitCount: Int64 =
            switch stage {
            case .transcribing: 0
            case .identifyingSpeakers: 1
            case .summarizing: 2
            }
        await backgroundTaskClient.update(execution.id, stage.label, completedUnitCount, 3)
    }

    func end(_ execution: BackgroundExecution) async {
        await backgroundTaskClient.end(execution.id)
    }
}

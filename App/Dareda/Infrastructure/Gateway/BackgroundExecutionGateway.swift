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
    var end: @Sendable (_ execution: BackgroundExecution) async -> Void
}

nonisolated extension BackgroundExecutionGateway: DependencyKey {
    static let liveValue: BackgroundExecutionGateway = {
        let impl = BackgroundExecutionGatewayImpl()
        return BackgroundExecutionGateway(
            begin: impl.begin(onExpiration:),
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
        let identifier = await backgroundTaskClient.begin("ConversationAnalysis", onExpiration)
        return BackgroundExecution(id: identifier)
    }

    func end(_ execution: BackgroundExecution) async {
        await backgroundTaskClient.end(execution.id)
    }
}

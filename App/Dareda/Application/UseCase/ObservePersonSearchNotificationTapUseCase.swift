import Dependencies
import DependenciesMacros

/// 人物検索の通知のタップを監視する。タップされたら候補一覧を開く。
@DependencyClient
nonisolated struct ObservePersonSearchNotificationTapUseCase: Sendable {
    var execute: @Sendable () -> AsyncStream<Void> = { AsyncStream { $0.finish() } }
}

nonisolated extension ObservePersonSearchNotificationTapUseCase: DependencyKey {
    static let liveValue: ObservePersonSearchNotificationTapUseCase = {
        let impl = ObservePersonSearchNotificationTapUseCaseImpl()
        return ObservePersonSearchNotificationTapUseCase(execute: impl.execute)
    }()
}

nonisolated extension DependencyValues {
    var observePersonSearchNotificationTapUseCase: ObservePersonSearchNotificationTapUseCase {
        get { self[ObservePersonSearchNotificationTapUseCase.self] }
        set { self[ObservePersonSearchNotificationTapUseCase.self] = newValue }
    }
}

private nonisolated struct ObservePersonSearchNotificationTapUseCaseImpl: Sendable {
    @Dependency(\.userNotificationGateway) private var userNotificationGateway

    func execute() -> AsyncStream<Void> {
        userNotificationGateway.personSearchNotificationTaps()
    }
}

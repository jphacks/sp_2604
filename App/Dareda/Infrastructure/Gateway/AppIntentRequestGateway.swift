import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct AppIntentRequestGateway: Sendable {
    var send: @Sendable (_ request: AppIntentRequest) -> Void
    var requests: @Sendable () -> AsyncStream<AppIntentRequest> = { AsyncStream { $0.finish() } }
}

nonisolated extension AppIntentRequestGateway: DependencyKey {
    static let liveValue: AppIntentRequestGateway = {
        let impl = AppIntentRequestGatewayImpl()
        return AppIntentRequestGateway(
            send: impl.send(_:),
            requests: impl.requests
        )
    }()
}

nonisolated extension DependencyValues {
    var appIntentRequestGateway: AppIntentRequestGateway {
        get { self[AppIntentRequestGateway.self] }
        set { self[AppIntentRequestGateway.self] = newValue }
    }
}

private nonisolated struct AppIntentRequestGatewayImpl: Sendable {
    @Dependency(\.appIntentRequestClient) private var appIntentRequestClient

    func send(_ request: AppIntentRequest) {
        appIntentRequestClient.send(request.rawValue)
    }

    func requests() -> AsyncStream<AppIntentRequest> {
        let kinds = appIntentRequestClient.requests()
        return AsyncStream { continuation in
            let task = Task {
                for await kind in kinds {
                    if let request = AppIntentRequest(rawValue: kind) {
                        continuation.yield(request)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

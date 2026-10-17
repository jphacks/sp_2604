import Dependencies
import DependenciesMacros
import Logging

/// App Intent (Live Activity・コントロール・ショートカット) からの依頼を画面に渡す。
@DependencyClient
nonisolated struct AppIntentRequestService: Sendable {
    var send: @Sendable (_ request: AppIntentRequest) -> Void
    var requests: @Sendable () -> AsyncStream<AppIntentRequest> = { AsyncStream { $0.finish() } }
}

nonisolated extension AppIntentRequestService: DependencyKey {
    static let liveValue: AppIntentRequestService = {
        let impl = AppIntentRequestServiceImpl()
        return AppIntentRequestService(
            send: impl.send(_:),
            requests: impl.requests
        )
    }()
}

nonisolated extension DependencyValues {
    var appIntentRequestService: AppIntentRequestService {
        get { self[AppIntentRequestService.self] }
        set { self[AppIntentRequestService.self] = newValue }
    }
}

private nonisolated struct AppIntentRequestServiceImpl: Sendable {
    private static let logger = Logger(label: "Dareda.AppIntentRequestService")

    @Dependency(\.appIntentRequestGateway) private var appIntentRequestGateway

    func send(_ request: AppIntentRequest) {
        Self.logger.info("App intent requested", metadata: ["request": "\(request.rawValue)"])
        appIntentRequestGateway.send(request)
    }

    func requests() -> AsyncStream<AppIntentRequest> {
        appIntentRequestGateway.requests()
    }
}

import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct AppSettingsGateway: Sendable {
    var open: @Sendable () async throws -> Void
}

nonisolated extension AppSettingsGateway: DependencyKey {
    static let liveValue: AppSettingsGateway = {
        let impl = AppSettingsGatewayImpl()
        return AppSettingsGateway(open: impl.open)
    }()
}

nonisolated extension DependencyValues {
    var appSettingsGateway: AppSettingsGateway {
        get { self[AppSettingsGateway.self] }
        set { self[AppSettingsGateway.self] = newValue }
    }
}

private nonisolated struct AppSettingsGatewayImpl: Sendable {
    @Dependency(\.appSettingsClient) private var appSettingsClient

    func open() async throws {
        try await appSettingsClient.open()
    }
}

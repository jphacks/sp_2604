import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct AppInfoGateway: Sendable {
    var version: @Sendable () -> AppVersion = { AppVersion(version: "", build: "") }
}

nonisolated extension AppInfoGateway: DependencyKey {
    static let liveValue: AppInfoGateway = {
        let impl = AppInfoGatewayImpl()
        return AppInfoGateway(version: impl.version)
    }()
}

nonisolated extension DependencyValues {
    var appInfoGateway: AppInfoGateway {
        get { self[AppInfoGateway.self] }
        set { self[AppInfoGateway.self] = newValue }
    }
}

private nonisolated struct AppInfoGatewayImpl: Sendable {
    @Dependency(\.bundleClient) private var bundleClient

    func version() -> AppVersion {
        AppVersion(
            version: bundleClient.infoValue(forKey: "CFBundleShortVersionString") as? String ?? "",
            build: bundleClient.infoValue(forKey: "CFBundleVersion") as? String ?? ""
        )
    }
}

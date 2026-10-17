import Dependencies
import DependenciesMacros
import UIKit

@DependencyClient
nonisolated struct AppSettingsClient: Sendable {
    var open: @Sendable () async throws -> Void
}

nonisolated extension AppSettingsClient: DependencyKey {
    static let liveValue: AppSettingsClient = {
        let impl = AppSettingsClientImpl()
        return AppSettingsClient(open: impl.open)
    }()

    static let testValue = AppSettingsClient.inMemory()
    static let previewValue = AppSettingsClient.inMemory()
}

nonisolated extension DependencyValues {
    var appSettingsClient: AppSettingsClient {
        get { self[AppSettingsClient.self] }
        set { self[AppSettingsClient.self] = newValue }
    }
}

nonisolated extension AppSettingsClient {
    static func inMemory(open: @escaping @Sendable () async throws -> Void = {}) -> Self {
        Self(open: open)
    }
}

private nonisolated struct AppSettingsClientImpl: Sendable {
    func open() async throws {
        try await Self.openSettings()
    }

    @MainActor
    private static func openSettings() async throws {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              await UIApplication.shared.open(url) else {
            throw CocoaError(.featureUnsupported)
        }
    }
}

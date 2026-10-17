import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct OpenAppSettingsUseCase: Sendable {
    var execute: @Sendable () async throws -> Void
}

nonisolated extension OpenAppSettingsUseCase: DependencyKey {
    static let liveValue: OpenAppSettingsUseCase = {
        let impl = OpenAppSettingsUseCaseImpl()
        return OpenAppSettingsUseCase(execute: impl.execute)
    }()
}

nonisolated extension DependencyValues {
    var openAppSettingsUseCase: OpenAppSettingsUseCase {
        get { self[OpenAppSettingsUseCase.self] }
        set { self[OpenAppSettingsUseCase.self] = newValue }
    }
}

private nonisolated struct OpenAppSettingsUseCaseImpl: Sendable {
    @Dependency(\.appSettingsGateway) private var appSettingsGateway

    func execute() async throws {
        try await appSettingsGateway.open()
    }
}

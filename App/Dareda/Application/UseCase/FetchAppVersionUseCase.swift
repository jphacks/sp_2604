import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct FetchAppVersionUseCase: Sendable {
    var execute: @Sendable () -> AppVersion = { AppVersion(version: "", build: "") }
}

nonisolated extension FetchAppVersionUseCase: DependencyKey {
    static let liveValue: FetchAppVersionUseCase = {
        let impl = FetchAppVersionUseCaseImpl()
        return FetchAppVersionUseCase(execute: impl.execute)
    }()
}

nonisolated extension DependencyValues {
    var fetchAppVersionUseCase: FetchAppVersionUseCase {
        get { self[FetchAppVersionUseCase.self] }
        set { self[FetchAppVersionUseCase.self] = newValue }
    }
}

private nonisolated struct FetchAppVersionUseCaseImpl: Sendable {
    @Dependency(\.appInfoGateway) private var appInfoGateway

    func execute() -> AppVersion {
        appInfoGateway.version()
    }
}

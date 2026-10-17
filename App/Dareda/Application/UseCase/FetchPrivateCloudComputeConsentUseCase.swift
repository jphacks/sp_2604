import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct FetchPrivateCloudComputeConsentUseCase: Sendable {
    var execute: @Sendable () -> PrivateCloudComputeConsent = { .undetermined }
}

nonisolated extension FetchPrivateCloudComputeConsentUseCase: DependencyKey {
    static let liveValue: FetchPrivateCloudComputeConsentUseCase = {
        let impl = FetchPrivateCloudComputeConsentUseCaseImpl()
        return FetchPrivateCloudComputeConsentUseCase(execute: impl.execute)
    }()
}

nonisolated extension DependencyValues {
    var fetchPrivateCloudComputeConsentUseCase: FetchPrivateCloudComputeConsentUseCase {
        get { self[FetchPrivateCloudComputeConsentUseCase.self] }
        set { self[FetchPrivateCloudComputeConsentUseCase.self] = newValue }
    }
}

private nonisolated struct FetchPrivateCloudComputeConsentUseCaseImpl: Sendable {
    @Dependency(\.privateCloudComputeConsentRepository) private var privateCloudComputeConsentRepository

    func execute() -> PrivateCloudComputeConsent {
        privateCloudComputeConsentRepository.get()
    }
}

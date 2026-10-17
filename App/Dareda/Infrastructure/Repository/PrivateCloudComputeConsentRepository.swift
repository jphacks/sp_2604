import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct PrivateCloudComputeConsentRepository: Sendable {
    var get: @Sendable () -> PrivateCloudComputeConsent = { .undetermined }
    var set: @Sendable (_ consent: PrivateCloudComputeConsent) -> Void
}

nonisolated extension PrivateCloudComputeConsentRepository: DependencyKey {
    static let liveValue: PrivateCloudComputeConsentRepository = {
        let impl = PrivateCloudComputeConsentRepositoryImpl()
        return PrivateCloudComputeConsentRepository(
            get: impl.get,
            set: impl.set(_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var privateCloudComputeConsentRepository: PrivateCloudComputeConsentRepository {
        get { self[PrivateCloudComputeConsentRepository.self] }
        set { self[PrivateCloudComputeConsentRepository.self] = newValue }
    }
}

private nonisolated struct PrivateCloudComputeConsentRepositoryImpl: Sendable {
    @Dependency(\.userDefaultsClient) private var userDefaultsClient

    private static let key = "privateCloudComputeConsent"

    func get() -> PrivateCloudComputeConsent {
        guard let rawValue = userDefaultsClient.value(forKey: Self.key) as? String else {
            return .undetermined
        }
        return PrivateCloudComputeConsent(rawValue: rawValue) ?? .undetermined
    }

    func set(_ consent: PrivateCloudComputeConsent) {
        userDefaultsClient.setValue(value: consent.rawValue, forKey: Self.key)
    }
}

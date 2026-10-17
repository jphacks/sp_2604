import Dependencies
import DependenciesMacros
import FoundationModels

@DependencyClient
nonisolated struct DeviceAvailabilityGateway: Sendable {
    var get: @Sendable () -> DeviceAvailability = { .unsupported }
}

nonisolated extension DeviceAvailabilityGateway: DependencyKey {
    static let liveValue: DeviceAvailabilityGateway = {
        let impl = DeviceAvailabilityGatewayImpl()
        return DeviceAvailabilityGateway(
            get: impl.get
        )
    }()
}

nonisolated extension DependencyValues {
    var deviceAvailabilityGateway: DeviceAvailabilityGateway {
        get { self[DeviceAvailabilityGateway.self] }
        set { self[DeviceAvailabilityGateway.self] = newValue }
    }
}

private nonisolated struct DeviceAvailabilityGatewayImpl: Sendable {
    @Dependency(\.foundationModelsClient) private var foundationModelsClient

    func get() -> DeviceAvailability {
        switch foundationModelsClient.availability() {
        case .available:
            .available
        case let .unavailable(reason):
            switch reason {
            case .deviceNotEligible:
                .unsupported
            case .appleIntelligenceNotEnabled:
                .temporarilyUnavailable(.appleIntelligenceDisabled)
            case .modelNotReady:
                .temporarilyUnavailable(.modelNotReady)
            @unknown default:
                .temporarilyUnavailable(.unknown)
            }
        }
    }
}

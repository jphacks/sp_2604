import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct CheckDeviceAvailabilityUseCase: Sendable {
    var execute: @Sendable () -> DeviceAvailability = { .unsupported }
}

nonisolated extension CheckDeviceAvailabilityUseCase: DependencyKey {
    static let liveValue: CheckDeviceAvailabilityUseCase = {
        let impl = CheckDeviceAvailabilityUseCaseImpl()
        return CheckDeviceAvailabilityUseCase(
            execute: impl.execute
        )
    }()
}

nonisolated extension DependencyValues {
    var checkDeviceAvailabilityUseCase: CheckDeviceAvailabilityUseCase {
        get { self[CheckDeviceAvailabilityUseCase.self] }
        set { self[CheckDeviceAvailabilityUseCase.self] = newValue }
    }
}

private nonisolated struct CheckDeviceAvailabilityUseCaseImpl: Sendable {
    @Dependency(\.deviceAvailabilityGateway) private var deviceAvailabilityGateway

    func execute() -> DeviceAvailability {
        deviceAvailabilityGateway.get()
    }
}

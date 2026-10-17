import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct RequestRecordingPermissionUseCase: Sendable {
    var execute: @Sendable () async -> RecordingPermission = { .undetermined }
}

nonisolated extension RequestRecordingPermissionUseCase: DependencyKey {
    static let liveValue: RequestRecordingPermissionUseCase = {
        let impl = RequestRecordingPermissionUseCaseImpl()
        return RequestRecordingPermissionUseCase(execute: impl.execute)
    }()
}

nonisolated extension DependencyValues {
    var requestRecordingPermissionUseCase: RequestRecordingPermissionUseCase {
        get { self[RequestRecordingPermissionUseCase.self] }
        set { self[RequestRecordingPermissionUseCase.self] = newValue }
    }
}

private nonisolated struct RequestRecordingPermissionUseCaseImpl: Sendable {
    @Dependency(\.audioRecordingGateway) private var audioRecordingGateway

    func execute() async -> RecordingPermission {
        let permission = audioRecordingGateway.permission()
        guard permission == .undetermined else { return permission }
        return await audioRecordingGateway.requestPermission()
    }
}

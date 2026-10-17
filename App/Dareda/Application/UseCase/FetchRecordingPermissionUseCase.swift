import Dependencies
import DependenciesMacros

/// マイクの利用権限を、許可を求めずに取得する。
@DependencyClient
nonisolated struct FetchRecordingPermissionUseCase: Sendable {
    var execute: @Sendable () -> RecordingPermission = { .undetermined }
}

nonisolated extension FetchRecordingPermissionUseCase: DependencyKey {
    static let liveValue: FetchRecordingPermissionUseCase = {
        let impl = FetchRecordingPermissionUseCaseImpl()
        return FetchRecordingPermissionUseCase(execute: impl.execute)
    }()
}

nonisolated extension DependencyValues {
    var fetchRecordingPermissionUseCase: FetchRecordingPermissionUseCase {
        get { self[FetchRecordingPermissionUseCase.self] }
        set { self[FetchRecordingPermissionUseCase.self] = newValue }
    }
}

private nonisolated struct FetchRecordingPermissionUseCaseImpl: Sendable {
    @Dependency(\.audioRecordingGateway) private var audioRecordingGateway

    func execute() -> RecordingPermission {
        audioRecordingGateway.permission()
    }
}

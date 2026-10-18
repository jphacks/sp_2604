import Dependencies
import DependenciesMacros
import Foundation
import Logging

/// プロフィールと出会い記録を削除し、Apple Watch の一覧に反映する。
@DependencyClient
nonisolated struct DeleteProfileUseCase: Sendable {
    var execute: @Sendable (_ id: Profile.ID) async throws -> Void
}

nonisolated extension DeleteProfileUseCase: DependencyKey {
    static let liveValue: DeleteProfileUseCase = {
        let impl = DeleteProfileUseCaseImpl()
        return DeleteProfileUseCase(
            execute: impl.execute(id:)
        )
    }()
}

nonisolated extension DependencyValues {
    var deleteProfileUseCase: DeleteProfileUseCase {
        get { self[DeleteProfileUseCase.self] }
        set { self[DeleteProfileUseCase.self] = newValue }
    }
}

private nonisolated struct DeleteProfileUseCaseImpl: Sendable {
    private static let logger = Logger(label: "Dareda.DeleteProfileUseCase")

    @Dependency(\.profileRepository) private var profileRepository
    @Dependency(\.watchSyncService) private var watchSyncService

    func execute(id: Profile.ID) async throws {
        Self.logger.info("Profile deletion started")
        do {
            try await profileRepository.delete(id)
        } catch {
            if error is CancellationError || Task.isCancelled {
                Self.logger.debug("Profile deletion cancelled")
            } else {
                Self.logger.error("Profile deletion failed", metadata: ["error_type": "\(type(of: error))"])
            }
            throw error
        }
        Self.logger.info("Profile deletion completed")
        await watchSyncService.syncProfiles()
    }
}

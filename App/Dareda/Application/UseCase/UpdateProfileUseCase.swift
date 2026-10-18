import Dependencies
import DependenciesMacros
import Foundation
import Logging

/// プロフィールの名前・所属と前回の会話 (日時・場所・要約) を更新し、Apple Watch の一覧に反映する。
@DependencyClient
nonisolated struct UpdateProfileUseCase: Sendable {
    var execute: @Sendable (
        _ id: Profile.ID,
        _ name: String,
        _ affiliation: String,
        _ metAt: Date,
        _ place: Place?,
        _ summary: String
    ) async throws -> Void
}

nonisolated extension UpdateProfileUseCase: DependencyKey {
    static let liveValue: UpdateProfileUseCase = {
        let impl = UpdateProfileUseCaseImpl()
        return UpdateProfileUseCase(
            execute: impl.execute(id:name:affiliation:metAt:place:summary:)
        )
    }()
}

nonisolated extension DependencyValues {
    var updateProfileUseCase: UpdateProfileUseCase {
        get { self[UpdateProfileUseCase.self] }
        set { self[UpdateProfileUseCase.self] = newValue }
    }
}

private nonisolated struct UpdateProfileUseCaseImpl: Sendable {
    private static let logger = Logger(label: "Dareda.UpdateProfileUseCase")

    @Dependency(\.profileRepository) private var profileRepository
    @Dependency(\.encounterRepository) private var encounterRepository
    @Dependency(\.uuid) private var uuid
    @Dependency(\.watchSyncService) private var watchSyncService

    func execute(
        id: Profile.ID,
        name: String,
        affiliation: String,
        metAt: Date,
        place: Place?,
        summary: String
    ) async throws {
        Self.logger.info("Profile update started")
        do {
            // 前回の会話が未登録のプロフィールには、新しく作る
            let encounterID = try await encounterRepository.get(id)?.id ?? uuid()
            try await profileRepository.update(
                id,
                name.trimmingCharacters(in: .whitespacesAndNewlines),
                affiliation.trimmingCharacters(in: .whitespacesAndNewlines),
                Encounter(id: encounterID, profileID: id, summary: summary, metAt: metAt, place: place)
            )
        } catch {
            if error is CancellationError || Task.isCancelled {
                Self.logger.debug("Profile update cancelled")
            } else {
                Self.logger.error("Profile update failed", metadata: ["error_type": "\(type(of: error))"])
            }
            throw error
        }
        Self.logger.info("Profile update completed")
        await watchSyncService.syncProfiles()
    }
}

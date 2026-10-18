import Dependencies
import DependenciesMacros
import Foundation
import Logging

/// 人物検索で見つかった人物の前回の会話を、最新の会話 (日時・要約) で上書きし、Apple Watch の一覧に反映する。
/// 場所は最新の会話では分からないため、未設定に戻す。名前・所属・声のベクトルは変更しない。
@DependencyClient
nonisolated struct OverwriteEncounterUseCase: Sendable {
    var execute: @Sendable (_ profileID: Profile.ID, _ metAt: Date, _ summary: String) async throws -> Void
}

nonisolated extension OverwriteEncounterUseCase: DependencyKey {
    static let liveValue: OverwriteEncounterUseCase = {
        let impl = OverwriteEncounterUseCaseImpl()
        return OverwriteEncounterUseCase(
            execute: impl.execute(profileID:metAt:summary:)
        )
    }()
}

nonisolated extension DependencyValues {
    var overwriteEncounterUseCase: OverwriteEncounterUseCase {
        get { self[OverwriteEncounterUseCase.self] }
        set { self[OverwriteEncounterUseCase.self] = newValue }
    }
}

private nonisolated struct OverwriteEncounterUseCaseImpl: Sendable {
    private static let logger = Logger(label: "Dareda.OverwriteEncounterUseCase")

    @Dependency(\.profileRepository) private var profileRepository
    @Dependency(\.encounterRepository) private var encounterRepository
    @Dependency(\.uuid) private var uuid
    @Dependency(\.watchSyncService) private var watchSyncService

    func execute(profileID: Profile.ID, metAt: Date, summary: String) async throws {
        Self.logger.info("Encounter overwrite started")
        do {
            guard let profile = try await profileRepository.get(profileID) else { return }
            let encounterID = try await encounterRepository.get(profileID)?.id ?? uuid()
            try await profileRepository.update(
                profile.id,
                profile.name,
                profile.affiliation,
                Encounter(id: encounterID, profileID: profile.id, summary: summary, metAt: metAt, place: nil)
            )
        } catch {
            if error is CancellationError || Task.isCancelled {
                Self.logger.debug("Encounter overwrite cancelled")
            } else {
                Self.logger.error("Encounter overwrite failed", metadata: ["error_type": "\(type(of: error))"])
            }
            throw error
        }
        Self.logger.info("Encounter overwrite completed")
        await watchSyncService.syncProfiles()
    }
}

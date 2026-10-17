import Dependencies
import DependenciesMacros
import Foundation

/// 新規登録を保存し、録音と処理セッションの一時データを削除する。保存したプロフィールの ID を返す。
@DependencyClient
nonisolated struct RegisterProfileUseCase: Sendable {
    var execute: @Sendable (
        _ name: String,
        _ affiliation: String,
        _ metAt: Date,
        _ place: Place?,
        _ summary: String,
        _ partnerVector: [Float],
        _ recording: Recording,
        _ session: ProcessingSession
    ) async throws -> Profile.ID
}

nonisolated extension RegisterProfileUseCase: DependencyKey {
    static let liveValue: RegisterProfileUseCase = {
        let impl = RegisterProfileUseCaseImpl()
        return RegisterProfileUseCase(
            execute: impl.execute(name:affiliation:metAt:place:summary:partnerVector:recording:session:)
        )
    }()
}

nonisolated extension DependencyValues {
    var registerProfileUseCase: RegisterProfileUseCase {
        get { self[RegisterProfileUseCase.self] }
        set { self[RegisterProfileUseCase.self] = newValue }
    }
}

private nonisolated struct RegisterProfileUseCaseImpl: Sendable {
    @Dependency(\.profileRepository) private var profileRepository
    @Dependency(\.recordingService) private var recordingService
    @Dependency(\.processingSessionService) private var processingSessionService
    @Dependency(\.uuid) private var uuid

    func execute(
        name: String,
        affiliation: String,
        metAt: Date,
        place: Place?,
        summary: String,
        partnerVector: [Float],
        recording: Recording,
        session: ProcessingSession
    ) async throws -> Profile.ID {
        let profile = Profile(
            id: uuid(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            affiliation: affiliation.trimmingCharacters(in: .whitespacesAndNewlines),
            vector: partnerVector
        )
        let encounter = Encounter(id: uuid(), profileID: profile.id, summary: summary, metAt: metAt, place: place)
        try await profileRepository.add(profile, encounter)
        // 保存済みのため、削除に失敗しても登録は成功とする (再試行で二重に保存させない)。
        // 残った一時データは次回起動時のクリーンアップで削除される。
        try? recordingService.discard(recording)
        try? await processingSessionService.discard(session)
        return profile.id
    }
}

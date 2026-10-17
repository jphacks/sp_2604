import Dependencies
import DependenciesMacros
import Foundation
import Logging

/// iPhone の状態を Apple Watch に反映し、Apple Watch からの録音と操作を受け取る。
///
/// プロフィール一覧・録音の可否・処理状況を 1 つのスナップショットにまとめ、いずれかが変わるたびに送り直す。
@DependencyClient
nonisolated struct WatchSyncService: Sendable {
    var activate: @Sendable () -> Void
    /// 保存済みのプロフィールを読み直して送る。
    var syncProfiles: @Sendable () async -> Void
    var updateRecordingAvailability: @Sendable (_ isAvailable: Bool) -> Void
    /// 処理状況を送る。処理を終えたら `nil` を渡す。
    var updateProcessing: @Sendable (_ state: WatchProcessingState?) -> Void
    var recordings: @Sendable () -> AsyncStream<WatchRecording> = { AsyncStream { $0.finish() } }
    var commands: @Sendable () -> AsyncStream<WatchCommand> = { AsyncStream { $0.finish() } }
}

nonisolated extension WatchSyncService: DependencyKey {
    static let liveValue: WatchSyncService = {
        let impl = WatchSyncServiceImpl()
        return WatchSyncService(
            activate: impl.activate,
            syncProfiles: impl.syncProfiles,
            updateRecordingAvailability: impl.updateRecordingAvailability(_:),
            updateProcessing: impl.updateProcessing(_:),
            recordings: impl.recordings,
            commands: impl.commands
        )
    }()

    static let testValue = WatchSyncService(
        activate: {},
        syncProfiles: {},
        updateRecordingAvailability: { _ in },
        updateProcessing: { _ in },
        recordings: { AsyncStream { $0.finish() } },
        commands: { AsyncStream { $0.finish() } }
    )
    static let previewValue = testValue
}

nonisolated extension DependencyValues {
    var watchSyncService: WatchSyncService {
        get { self[WatchSyncService.self] }
        set { self[WatchSyncService.self] = newValue }
    }
}

nonisolated extension WatchProfile {
    init(_ detail: ProfileDetailServiceModel) {
        self.init(
            id: detail.profile.id,
            name: detail.profile.name,
            affiliation: detail.profile.affiliation,
            summary: detail.encounter?.summary,
            metAt: detail.encounter?.metAt,
            placeName: detail.encounter?.place?.name
        )
    }
}

private nonisolated struct WatchSyncServiceImpl: Sendable {
    private static let logger = Logger(label: "Dareda.WatchSyncService")

    @Dependency(\.watchSyncGateway) private var watchSyncGateway
    @Dependency(\.profileRepository) private var profileRepository
    @Dependency(\.encounterRepository) private var encounterRepository

    private let snapshot = LockIsolated(WatchSnapshot.empty)

    func activate() {
        watchSyncGateway.activate()
    }

    func syncProfiles() async {
        do {
            var profiles: [WatchProfile] = []
            for profile in try await profileRepository.getAll() {
                let encounter = try await encounterRepository.get(profile.id)
                profiles.append(WatchProfile(ProfileDetailServiceModel(profile: profile, encounter: encounter)))
            }
            let synced = profiles
            update { $0.profiles = synced }
        } catch {
            // 送れなくても Apple Watch には前回の一覧が残るため、次の同期を待つ
            Self.logger.error("Watch profile sync failed", metadata: ["error_type": "\(type(of: error))"])
        }
    }

    func updateRecordingAvailability(_ isAvailable: Bool) {
        update { $0.isRecordingAvailable = isAvailable }
    }

    func updateProcessing(_ state: WatchProcessingState?) {
        update { $0.processing = state }
    }

    func recordings() -> AsyncStream<WatchRecording> { watchSyncGateway.recordings() }
    func commands() -> AsyncStream<WatchCommand> { watchSyncGateway.commands() }

    private func update(_ change: @Sendable (inout WatchSnapshot) -> Void) {
        let current = snapshot.withValue { value in
            change(&value)
            return value
        }
        do {
            try watchSyncGateway.send(current)
        } catch {
            Self.logger.error("Watch snapshot send failed", metadata: ["error_type": "\(type(of: error))"])
        }
    }
}

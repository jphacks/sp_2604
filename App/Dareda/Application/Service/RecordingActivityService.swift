import Dependencies
import DependenciesMacros
import Logging

/// 録音から人物検索の結果までを Live Activity に表示する。
/// 表示できなくてもアプリ内で操作を続けられるため、失敗はログに残すだけで呼び出し元に返さない。
@DependencyClient
nonisolated struct RecordingActivityService: Sendable {
    /// 録音の開始時に、前回の Live Activity を閉じて新しく表示する。
    var start: @Sendable (_ activity: RecordingActivity) async -> Void
    var update: @Sendable (_ activity: RecordingActivity) async -> Void
    var end: @Sendable () async -> Void
}

nonisolated extension RecordingActivityService: DependencyKey {
    static let liveValue: RecordingActivityService = {
        let impl = RecordingActivityServiceImpl()
        return RecordingActivityService(
            start: impl.start(_:),
            update: impl.update(_:),
            end: impl.end
        )
    }()
}

nonisolated extension DependencyValues {
    var recordingActivityService: RecordingActivityService {
        get { self[RecordingActivityService.self] }
        set { self[RecordingActivityService.self] = newValue }
    }
}

private nonisolated struct RecordingActivityServiceImpl: Sendable {
    private static let logger = Logger(label: "Dareda.RecordingActivityService")

    @Dependency(\.recordingActivityGateway) private var recordingActivityGateway

    func start(_ activity: RecordingActivity) async {
        do {
            try await recordingActivityGateway.start(activity)
            Self.logger.info("Live Activity started")
        } catch {
            Self.logger.warning("Live Activity start failed", metadata: ["error_type": "\(type(of: error))"])
        }
    }

    func update(_ activity: RecordingActivity) async {
        do {
            try await recordingActivityGateway.update(activity)
        } catch {
            Self.logger.warning("Live Activity update failed", metadata: ["error_type": "\(type(of: error))"])
        }
    }

    func end() async {
        await recordingActivityGateway.end()
        Self.logger.info("Live Activity ended")
    }
}

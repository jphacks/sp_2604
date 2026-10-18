import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct RecordingActivityGateway: Sendable {
    /// 表示中の Live Activity を閉じてから、新しく表示する。
    var start: @Sendable (_ activity: RecordingActivity) async throws -> Void
    /// 表示中の Live Activity を更新する。表示していなければ新しく表示する。
    var update: @Sendable (_ activity: RecordingActivity) async throws -> Void
    var end: @Sendable () async -> Void
}

nonisolated extension RecordingActivityGateway: DependencyKey {
    static let liveValue: RecordingActivityGateway = {
        let impl = RecordingActivityGatewayImpl()
        return RecordingActivityGateway(
            start: impl.start(_:),
            update: impl.update(_:),
            end: impl.end
        )
    }()
}

nonisolated extension DependencyValues {
    var recordingActivityGateway: RecordingActivityGateway {
        get { self[RecordingActivityGateway.self] }
        set { self[RecordingActivityGateway.self] = newValue }
    }
}

private nonisolated struct RecordingActivityGatewayImpl: Sendable {
    @Dependency(\.liveActivityClient) private var liveActivityClient

    func start(_ activity: RecordingActivity) async throws {
        try await liveActivityClient.start(Self.state(for: activity))
    }

    func update(_ activity: RecordingActivity) async throws {
        try await liveActivityClient.update(Self.state(for: activity))
    }

    func end() async {
        await liveActivityClient.end()
    }

    private static func state(for activity: RecordingActivity) -> RecordingActivityAttributes.ContentState {
        let phase: RecordingActivityAttributes.Phase =
            switch activity {
            case let .recording(startedAt):
                .recording(startedAt: startedAt)
            case let .analyzing(stage):
                .analyzing(stage: stage)
            case let .candidate(profile, encounter):
                .candidate(RecordingActivityAttributes.Candidate(
                    name: profile.name,
                    affiliation: profile.affiliation,
                    metAt: encounter?.metAt,
                    placeName: encounter?.place?.name,
                    summary: encounter?.summary
                ))
            case .needsAdditionalRecording:
                .message("相手の声が足りません。アプリで追加録音してください。")
            case .needsSelfSelection:
                .message("あなたの声を判定できませんでした。アプリで選んでください。")
            case .noCandidate:
                .message("登録済みの人物が見つかりませんでした。")
            case .failed:
                .message("解析に失敗しました。アプリでもう一度お試しください。")
            }
        return RecordingActivityAttributes.ContentState(phase: phase)
    }
}

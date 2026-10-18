import ActivityKit
import Dependencies
import DependenciesMacros
import Foundation

/// ActivityKit による録音の Live Activity の表示。アプリ内で同時に表示するのは 1 つだけ。
@DependencyClient
nonisolated struct LiveActivityClient: Sendable {
    /// 表示中の Live Activity を閉じてから、新しく表示する。
    var start: @Sendable (_ state: RecordingActivityAttributes.ContentState) async throws -> Void
    /// 表示中の Live Activity を更新する。表示していなければ新しく表示する。
    var update: @Sendable (_ state: RecordingActivityAttributes.ContentState) async throws -> Void
    /// 表示中の Live Activity をすぐに閉じる。
    var end: @Sendable () async -> Void
}

nonisolated extension LiveActivityClient: DependencyKey {
    static let liveValue: LiveActivityClient = {
        let impl = LiveActivityClientImpl()
        return LiveActivityClient(
            start: impl.start(_:),
            update: impl.update(_:),
            end: impl.end
        )
    }()

    static let testValue = LiveActivityClient.inMemory()
    static let previewValue = LiveActivityClient.inMemory()
}

nonisolated extension DependencyValues {
    var liveActivityClient: LiveActivityClient {
        get { self[LiveActivityClient.self] }
        set { self[LiveActivityClient.self] = newValue }
    }
}

private nonisolated struct LiveActivityClientImpl: Sendable {
    func start(_ state: RecordingActivityAttributes.ContentState) async throws {
        await end()
        try request(state)
    }

    func update(_ state: RecordingActivityAttributes.ContentState) async throws {
        let activities = Activity<RecordingActivityAttributes>.activities
        guard !activities.isEmpty else {
            try request(state)
            return
        }
        for activity in activities {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end() async {
        for activity in Activity<RecordingActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func request(_ state: RecordingActivityAttributes.ContentState) throws {
        // Live Activity を許可していない場合は表示しない。アプリ内の表示だけで操作できる
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try Activity.request(
            attributes: RecordingActivityAttributes(),
            content: ActivityContent(state: state, staleDate: nil)
        )
    }
}

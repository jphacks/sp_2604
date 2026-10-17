import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct RecordingService: Sendable {
    /// マイク権限を確認 (未決定なら要求) して録音を開始する。拒否済みなら `RecordingError.permissionDenied`。
    var start: @Sendable () async throws -> Recording
    /// 録音を停止し、録音済みの長さを反映した `Recording` を返す。
    var stop: @Sendable (_ recording: Recording) -> Recording = { $0 }
    /// 録音中のイベント (残り 1 分・上限到達による自動停止・中断) を流す。
    /// 上限到達・中断のイベントを流した時点で録音は停止済みで、ストリームは終了する。
    /// 呼び出し側が `Task` をキャンセルする (手動停止など) と監視も終了する。
    var events: @Sendable (_ recording: Recording) -> AsyncStream<RecordingEvent> = { _ in
        AsyncStream { $0.finish() }
    }
}

nonisolated extension RecordingService: DependencyKey {
    static let liveValue: RecordingService = {
        let impl = RecordingServiceImpl()
        return RecordingService(
            start: impl.start,
            stop: impl.stop(_:),
            events: impl.events(for:)
        )
    }()
}

nonisolated extension DependencyValues {
    var recordingService: RecordingService {
        get { self[RecordingService.self] }
        set { self[RecordingService.self] = newValue }
    }

    /// 録音の上限などの設定値。暫定値のため差し替え可能にしている。
    var recordingConfiguration: RecordingConfiguration {
        get { self[RecordingConfigurationKey.self] }
        set { self[RecordingConfigurationKey.self] = newValue }
    }
}

private nonisolated enum RecordingConfigurationKey: DependencyKey {
    static let liveValue = RecordingConfiguration.default
}

private nonisolated struct RecordingServiceImpl: Sendable {
    @Dependency(\.audioRecordingGateway) private var audioRecordingGateway
    @Dependency(\.recordingConfiguration) private var configuration
    @Dependency(\.continuousClock) private var clock

    func start() async throws -> Recording {
        var permission = audioRecordingGateway.permission()
        if permission == .undetermined {
            permission = await audioRecordingGateway.requestPermission()
        }
        guard permission == .granted else { throw RecordingError.permissionDenied }
        return try await audioRecordingGateway.start()
    }

    func stop(_ recording: Recording) -> Recording {
        audioRecordingGateway.stop(recording)
    }

    func events(for recording: Recording) -> AsyncStream<RecordingEvent> {
        let gateway = audioRecordingGateway
        let configuration = configuration
        let clock = clock
        let interruptions = gateway.interruptions()

        return AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: RecordingEvent?.self) { group in
                    group.addTask {
                        let untilWarning = max(configuration.maxDuration - configuration.warningRemaining, 0)
                        try? await clock.sleep(for: .seconds(untilWarning))
                        guard !Task.isCancelled else { return nil }
                        continuation.yield(.oneMinuteRemaining)
                        try? await clock.sleep(for: .seconds(configuration.maxDuration - untilWarning))
                        guard !Task.isCancelled else { return nil }
                        return .limitReached(gateway.stop(recording))
                    }
                    group.addTask {
                        for await _ in interruptions {
                            guard !Task.isCancelled else { return nil }
                            return .interrupted(gateway.stop(recording))
                        }
                        return nil
                    }
                    for await event in group {
                        if let event {
                            continuation.yield(event)
                            break
                        }
                    }
                    group.cancelAll()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

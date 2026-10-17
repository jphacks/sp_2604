import Dependencies
import DependenciesMacros
import Foundation
import Logging

@DependencyClient
nonisolated struct RecordingService: Sendable {
    /// マイク権限を確認 (未決定なら要求) して録音を開始する。拒否済みなら `RecordingError.permissionDenied`。
    var start: @Sendable () async throws -> Recording
    var stop: @Sendable (_ recording: Recording) -> Recording = { $0 }
    /// 録音中のイベント (残り 1 分・上限到達による自動停止・中断) を流す。
    /// 上限到達・中断のイベントを流した時点で録音は停止済みで、ストリームは終了する。
    /// 呼び出し側が `Task` をキャンセルする (手動停止など) と監視も終了する。
    var events: @Sendable (_ recording: Recording) -> AsyncStream<RecordingEvent> = { _ in
        AsyncStream { $0.finish() }
    }
    var interruptions: @Sendable () -> AsyncStream<Void> = { AsyncStream { $0.finish() } }
    var discard: @Sendable (_ recording: Recording) throws -> Void
}

nonisolated extension RecordingService: DependencyKey {
    static let liveValue: RecordingService = {
        let impl = RecordingServiceImpl()
        return RecordingService(
            start: impl.start,
            stop: impl.stop(_:),
            events: impl.events(for:),
            interruptions: impl.interruptions,
            discard: impl.discard(_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var recordingService: RecordingService {
        get { self[RecordingService.self] }
        set { self[RecordingService.self] = newValue }
    }
    var recordingConfiguration: RecordingConfiguration {
        get { self[RecordingConfigurationKey.self] }
        set { self[RecordingConfigurationKey.self] = newValue }
    }
}

private nonisolated enum RecordingConfigurationKey: DependencyKey {
    static let liveValue = RecordingConfiguration.default
}

private nonisolated struct RecordingServiceImpl: Sendable {
    private static let logger = Logger(label: "Dareda.RecordingService")

    @Dependency(\.audioRecordingGateway) private var audioRecordingGateway
    @Dependency(\.recordingConfiguration) private var configuration
    @Dependency(\.continuousClock) private var clock

    func start() async throws -> Recording {
        var permission = audioRecordingGateway.permission()
        if permission == .undetermined {
            permission = await audioRecordingGateway.requestPermission()
        }
        guard permission == .granted else {
            Self.logger.notice("Recording permission denied")
            throw RecordingError.permissionDenied
        }
        do {
            let recording = try await audioRecordingGateway.start()
            Self.logger.info("Recording started")
            return recording
        } catch {
            if error is CancellationError || Task.isCancelled {
                Self.logger.debug("Recording start cancelled")
            } else {
                Self.logger.error("Recording start failed", metadata: ["error_type": "\(type(of: error))"])
            }
            throw error
        }
    }

    func stop(_ recording: Recording) -> Recording {
        let stopped = audioRecordingGateway.stop(recording)
        Self.logger.info("Recording stopped")
        return stopped
    }
    func discard(_ recording: Recording) throws { try audioRecordingGateway.discard(recording) }
    func interruptions() -> AsyncStream<Void> { audioRecordingGateway.interruptions() }

    func events(for recording: Recording) -> AsyncStream<RecordingEvent> {
        let gateway = audioRecordingGateway
        let configuration = configuration
        let clock = clock
        let interruptions = gateway.interruptions()

        return AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: RecordingEvent?.self) { group in
                    group.addTask {
                        var hasWarned = false
                        while !Task.isCancelled {
                            let elapsed = gateway.elapsedTime()
                            continuation.yield(.elapsedTimeChanged(elapsed))
                            if elapsed >= configuration.maxDuration {
                                Self.logger.notice("Recording reached duration limit")
                                return .limitReached(gateway.stop(recording))
                            }
                            if !hasWarned, elapsed >= max(configuration.maxDuration - configuration.warningRemaining, 0) {
                                hasWarned = true
                                continuation.yield(.oneMinuteRemaining)
                            }
                            do {
                                try await clock.sleep(for: .milliseconds(200))
                            } catch { return nil }
                        }
                        return nil
                    }
                    group.addTask {
                        for await _ in interruptions {
                            guard !Task.isCancelled else { return nil }
                            Self.logger.notice("Recording interrupted")
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

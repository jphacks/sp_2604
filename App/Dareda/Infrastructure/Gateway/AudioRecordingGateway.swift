import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct AudioRecordingGateway: Sendable {
    var permission: @Sendable () -> RecordingPermission = { .undetermined }
    var requestPermission: @Sendable () async -> RecordingPermission = { .denied }
    /// 録音を開始し、開始時刻を記録した `Recording` を返す。
    var start: @Sendable () async throws -> Recording
    /// 録音を停止し、録音済みの長さを反映した `Recording` を返す。
    var stop: @Sendable (_ recording: Recording) -> Recording = { $0 }
    var elapsedTime: @Sendable () -> TimeInterval = { 0 }
    var discard: @Sendable (_ recording: Recording) throws -> Void
    var discardAll: @Sendable () throws -> Void
    var interruptions: @Sendable () -> AsyncStream<Void> = { AsyncStream { $0.finish() } }
}

nonisolated extension AudioRecordingGateway: DependencyKey {
    static let liveValue: AudioRecordingGateway = {
        let impl = AudioRecordingGatewayImpl()
        return AudioRecordingGateway(
            permission: impl.permission,
            requestPermission: impl.requestPermission,
            start: impl.start,
            stop: impl.stop(_:),
            elapsedTime: impl.elapsedTime,
            discard: impl.discard(_:),
            discardAll: impl.discardAll,
            interruptions: impl.interruptions
        )
    }()
}

nonisolated extension DependencyValues {
    var audioRecordingGateway: AudioRecordingGateway {
        get { self[AudioRecordingGateway.self] }
        set { self[AudioRecordingGateway.self] = newValue }
    }
}

private nonisolated struct AudioRecordingGatewayImpl: Sendable {
    @Dependency(\.audioRecorderClient) private var audioRecorderClient
    @Dependency(\.fileSystemClient) private var fileSystemClient
    @Dependency(\.date) private var date
    @Dependency(\.uuid) private var uuid

    func permission() -> RecordingPermission {
        Self.convert(audioRecorderClient.recordPermission())
    }

    func requestPermission() async -> RecordingPermission {
        await audioRecorderClient.requestRecordPermission() ? .granted : .denied
    }

    func start() async throws -> Recording {
        let fileURL = try await audioRecorderClient.start()
        return Recording(id: uuid(), fileURL: fileURL, startedAt: date.now, duration: 0)
    }

    func stop(_ recording: Recording) -> Recording {
        var recording = recording
        recording.duration = audioRecorderClient.stop()
        return recording
    }

    func elapsedTime() -> TimeInterval {
        audioRecorderClient.elapsedTime()
    }

    func discard(_ recording: Recording) throws {
        if fileSystemClient.fileExists(recording.fileURL) {
            try fileSystemClient.removeItem(recording.fileURL)
        }
    }

    func discardAll() throws {
        let directory = fileSystemClient.temporaryDirectory().appending(path: "Recordings")
        if fileSystemClient.fileExists(directory) {
            try fileSystemClient.removeItem(directory)
        }
    }

    func interruptions() -> AsyncStream<Void> {
        audioRecorderClient.interruptions()
    }

    private static func convert(_ permission: AudioRecorderClient.Permission) -> RecordingPermission {
        switch permission {
        case .undetermined: .undetermined
        case .granted: .granted
        case .denied: .denied
        }
    }
}

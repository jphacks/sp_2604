import Dependencies
import Foundation
import Observation

@Observable
final class VoiceEnrollmentViewModel {
    enum Action {
        case recordButtonTapped
        case stopButtonTapped
        case cancelButtonTapped
        case fileButtonTapped
        case fileImporterDismissed
        case fileSelected(Result<URL, any Error>)
    }

    enum Failure: Equatable {
        case permissionDenied
        case insufficientSpeech(TimeInterval)
        case unexpected
    }

    private(set) var isRecording = false
    private(set) var isProcessing = false
    private(set) var failure: Failure?
    private(set) var isCompleted = false
    private(set) var isCancelled = false
    private(set) var isFileImporterPresented = false

    @ObservationIgnored
    @Dependency(\.recordingService) private var recordingService
    @ObservationIgnored
    @Dependency(\.registerSelfVoiceUseCase) private var registerSelfVoiceUseCase
    @ObservationIgnored
    private var recording: Recording?

    func send(_ action: Action) {
        switch action {
        case .recordButtonTapped:
            Task { await start() }
        case .stopButtonTapped:
            Task { await stop() }
        case .cancelButtonTapped:
            cancel()
        case .fileButtonTapped:
            failure = nil
            isFileImporterPresented = true
        case .fileImporterDismissed:
            isFileImporterPresented = false
        case let .fileSelected(result):
            isFileImporterPresented = false
            switch result {
            case let .success(url):
                Task { await register(.file(url)) }
            case .failure:
                failure = .unexpected
            }
        }
    }

    private func start() async {
        failure = nil
        do {
            recording = try await recordingService.start()
            isRecording = true
        } catch RecordingError.permissionDenied {
            failure = .permissionDenied
        } catch {
            failure = .unexpected
        }
    }

    /// 録音中なら停止して破棄する。登録済みの声には触れない。
    private func cancel() {
        if let recording {
            self.recording = nil
            isRecording = false
            // 一時ファイルは次回起動時にも掃除されるため、破棄の失敗は無視する
            try? recordingService.discard(recordingService.stop(recording))
        }
        isCancelled = true
    }

    private func stop() async {
        guard let recording else { return }
        self.recording = nil
        isRecording = false
        await register(.recording(recordingService.stop(recording)))
    }

    private func register(_ source: SelfVoiceSource) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await registerSelfVoiceUseCase.execute(source)
            isCompleted = true
        } catch let SelfVoiceRegistrationError.insufficientSpeech(duration) {
            failure = .insufficientSpeech(duration)
        } catch {
            failure = .unexpected
        }
    }
}

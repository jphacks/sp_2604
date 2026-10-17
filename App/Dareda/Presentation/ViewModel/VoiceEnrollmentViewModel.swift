import Dependencies
import Foundation
import Observation

@Observable
final class VoiceEnrollmentViewModel {
    enum Action {
        case recordButtonTapped
        case stopButtonTapped
    }

    enum Failure: Equatable {
        case permissionDenied
        case insufficientSpeech(TimeInterval)
        case poorQuality(Set<SpeechQualityIssue>)
        case unexpected
    }

    private(set) var isRecording = false
    private(set) var isProcessing = false
    private(set) var failure: Failure?
    private(set) var isCompleted = false

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

    private func stop() async {
        guard let recording else { return }
        self.recording = nil
        isRecording = false
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await registerSelfVoiceUseCase.execute(recordingService.stop(recording))
            isCompleted = true
        } catch let SelfVoiceRegistrationError.insufficientSpeech(duration) {
            failure = .insufficientSpeech(duration)
        } catch let SelfVoiceRegistrationError.poorQuality(issues) {
            failure = .poorQuality(issues)
        } catch {
            failure = .unexpected
        }
    }
}

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct AnalyzeSpeechQualityUseCase: Sendable {
    var analyze: @Sendable (_ url: URL, _ thresholds: SpeechQualityThresholds) async throws -> SpeechQuality
}

nonisolated extension AnalyzeSpeechQualityUseCase: DependencyKey {
    static let liveValue: AnalyzeSpeechQualityUseCase = {
        let impl = AnalyzeSpeechQualityUseCaseImpl()
        return AnalyzeSpeechQualityUseCase(
            analyze: impl.analyze(url:thresholds:)
        )
    }()
}

nonisolated extension DependencyValues {
    var analyzeSpeechQualityUseCase: AnalyzeSpeechQualityUseCase {
        get { self[AnalyzeSpeechQualityUseCase.self] }
        set { self[AnalyzeSpeechQualityUseCase.self] = newValue }
    }
}

private nonisolated struct AnalyzeSpeechQualityUseCaseImpl: Sendable {
    @Dependency(\.audioFileGateway) private var audioFileGateway
    @Dependency(\.speechQualityService) private var speechQualityService

    func analyze(url: URL, thresholds: SpeechQualityThresholds) async throws -> SpeechQuality {
        let audio = try await audioFileGateway.samples(url)
        return speechQualityService.analyze(audio, thresholds)
    }
}

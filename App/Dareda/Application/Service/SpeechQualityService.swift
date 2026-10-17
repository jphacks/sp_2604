import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct SpeechQualityService: Sendable {
    /// 無音を除いた有効発話時間を算出する
    var analyze: @Sendable (_ audio: AudioSamples, _ thresholds: SpeechQualityThresholds) -> SpeechQuality = { _, _ in
        SpeechQuality(effectiveSpeechDuration: 0)
    }
}

nonisolated extension SpeechQualityService: DependencyKey {
    static let liveValue: SpeechQualityService = {
        let impl = SpeechQualityServiceImpl()
        return SpeechQualityService(
            analyze: impl.analyze(_:thresholds:)
        )
    }()
}

nonisolated extension DependencyValues {
    var speechQualityService: SpeechQualityService {
        get { self[SpeechQualityService.self] }
        set { self[SpeechQualityService.self] = newValue }
    }
}

private nonisolated struct SpeechQualityServiceImpl: Sendable {
    func analyze(_ audio: AudioSamples, thresholds: SpeechQualityThresholds) -> SpeechQuality {
        let frameLength = max(1, Int(audio.sampleRate * thresholds.frameDuration))

        var speechFrameCount = 0

        var start = 0
        while start < audio.samples.count {
            let end = min(start + frameLength, audio.samples.count)
            var squareSum: Float = 0
            for sample in audio.samples[start..<end] {
                squareSum += sample * sample
            }
            let rms = (squareSum / Float(end - start)).squareRoot()
            let levelDB = 20 * log10(max(rms, 1e-9))
            if levelDB >= thresholds.speechThresholdDB {
                speechFrameCount += 1
            }
            start = end
        }

        return SpeechQuality(
            effectiveSpeechDuration: Double(speechFrameCount) * thresholds.frameDuration
        )
    }
}

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct SpeechQualityService: Sendable {
    /// 無音を除いた有効発話時間を算出し、音量不足・音割れを判定する
    var analyze: @Sendable (_ audio: AudioSamples, _ thresholds: SpeechQualityThresholds) -> SpeechQuality = { _, _ in
        SpeechQuality(effectiveSpeechDuration: 0, issues: [])
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
        var speechLevelSum: Float = 0
        var clippedSampleCount = 0

        var start = 0
        while start < audio.samples.count {
            let end = min(start + frameLength, audio.samples.count)
            var squareSum: Float = 0
            for sample in audio.samples[start..<end] {
                squareSum += sample * sample
                if abs(sample) >= thresholds.clippingSampleLevel {
                    clippedSampleCount += 1
                }
            }
            let rms = (squareSum / Float(end - start)).squareRoot()
            let levelDB = 20 * log10(max(rms, 1e-9))
            if levelDB >= thresholds.speechThresholdDB {
                speechFrameCount += 1
                speechLevelSum += levelDB
            }
            start = end
        }

        var issues: Set<SpeechQualityIssue> = []
        if speechFrameCount == 0 || speechLevelSum / Float(speechFrameCount) < thresholds.minimumSpeechLevelDB {
            issues.insert(.tooQuiet)
        }
        if !audio.samples.isEmpty,
            Float(clippedSampleCount) / Float(audio.samples.count) >= thresholds.clippingRatio
        {
            issues.insert(.clipping)
        }

        return SpeechQuality(
            effectiveSpeechDuration: Double(speechFrameCount) * thresholds.frameDuration,
            issues: issues
        )
    }
}

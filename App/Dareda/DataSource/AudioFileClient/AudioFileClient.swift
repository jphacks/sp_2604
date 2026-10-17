import AVFoundation
import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct AudioFileClient: Sendable {
    /// 音声ファイルの先頭チャンネルを PCM サンプル (-1.0 ... 1.0) として読み出す
    var readSamples: @Sendable (_ url: URL) throws -> (sampleRate: Double, samples: [Float])
    /// 音声ファイルの長さ (秒) を返す
    var duration: @Sendable (_ url: URL) throws -> TimeInterval
}

nonisolated extension AudioFileClient: DependencyKey {
    static let liveValue: AudioFileClient = {
        let impl = AudioFileClientImpl()
        return AudioFileClient(
            readSamples: impl.readSamples(url:),
            duration: impl.duration(url:)
        )
    }()

    static let testValue = AudioFileClient()

    static let previewValue = AudioFileClient.inMemory(sampleRate: 16_000, samples: [])
}

nonisolated extension DependencyValues {
    var audioFileClient: AudioFileClient {
        get { self[AudioFileClient.self] }
        set { self[AudioFileClient.self] = newValue }
    }
}

private nonisolated struct AudioFileClientImpl: Sendable {
    func readSamples(url: URL) throws -> (sampleRate: Double, samples: [Float]) {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
            frameCount > 0
        else {
            return (format.sampleRate, [])
        }
        try file.read(into: buffer)
        guard let channel = buffer.floatChannelData?[0] else {
            return (format.sampleRate, [])
        }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        return (format.sampleRate, samples)
    }

    func duration(url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.processingFormat.sampleRate
    }
}

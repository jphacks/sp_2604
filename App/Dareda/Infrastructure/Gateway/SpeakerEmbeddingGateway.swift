import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct SpeakerEmbeddingGateway: Sendable {
    /// 音声区間 (複数可) から声の特徴ベクトルを生成する。
    /// 区間は連結して扱い、有効な音声が `minimumDuration` 秒に満たない場合は `SpeakerEmbeddingError.insufficientSpeech` を投げる。
    var embedding: @Sendable (_ segments: [VoiceSegment]) async throws -> VoiceEmbedding
}

nonisolated extension SpeakerEmbeddingGateway: DependencyKey {
    static let liveValue: SpeakerEmbeddingGateway = {
        let impl = SpeakerEmbeddingGatewayImpl()
        return SpeakerEmbeddingGateway(
            embedding: impl.embedding(of:)
        )
    }()
}

nonisolated extension DependencyValues {
    var speakerEmbeddingGateway: SpeakerEmbeddingGateway {
        get { self[SpeakerEmbeddingGateway.self] }
        set { self[SpeakerEmbeddingGateway.self] = newValue }
    }
}

nonisolated enum SpeakerEmbeddingError: Error, Equatable {
    case insufficientSpeech
    case invalidModelOutput
}

extension SpeakerEmbeddingGateway {
    /// ベクトルを生成できる音声の最短長 (秒)。
    nonisolated static let minimumDuration = ProvisionalParameters.speakerEmbeddingMinimumDuration
}

private nonisolated struct SpeakerEmbeddingGatewayImpl: Sendable {
    /// 1 回の推論に渡す音声の最大長 (秒)。長い音声はこの長さで分割し、長さで重み付けして平均する。
    private static let chunkDuration: TimeInterval = 30

    @Dependency(\.speakerEmbeddingModelClient) private var speakerEmbeddingModelClient

    func embedding(of segments: [VoiceSegment]) async throws -> VoiceEmbedding {
        let samples = segments.flatMap(\.samples)
        let sampleRate = VoiceSegment.sampleRate
        let minimumCount = Int(SpeakerEmbeddingGateway.minimumDuration * Double(sampleRate))
        guard samples.count >= minimumCount else {
            throw SpeakerEmbeddingError.insufficientSpeech
        }

        let chunkCount = Int(Self.chunkDuration * Double(sampleRate))
        var ranges: [Range<Int>] = []
        var start = 0
        while start < samples.count {
            let end = min(start + chunkCount, samples.count)
            ranges.append(start..<end)
            start = end
        }
        // 末尾が短すぎてモデルに渡せない場合は、直前の区間にまとめる
        if ranges.count > 1, let last = ranges.last, last.count < minimumCount {
            ranges.removeLast()
            ranges[ranges.count - 1] = ranges[ranges.count - 1].lowerBound..<samples.count
        }

        var sum: [Float] = []
        for range in ranges {
            let raw = try await speakerEmbeddingModelClient.embed(Array(samples[range]))
            guard let chunk = VoiceEmbedding(normalizing: raw) else {
                throw SpeakerEmbeddingError.invalidModelOutput
            }
            let weight = Float(range.count)
            if sum.isEmpty {
                sum = chunk.values.map { $0 * weight }
            } else if sum.count == chunk.values.count {
                for index in sum.indices {
                    sum[index] += chunk.values[index] * weight
                }
            } else {
                throw SpeakerEmbeddingError.invalidModelOutput
            }
        }
        guard let embedding = VoiceEmbedding(normalizing: sum) else {
            throw SpeakerEmbeddingError.invalidModelOutput
        }
        return embedding
    }
}

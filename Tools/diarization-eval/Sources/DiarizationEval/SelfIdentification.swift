import CoreML
import Foundation

/// アプリの ECAPA-TDNN で声のベクトルを生成する。
/// 処理はアプリの `SpeakerEmbeddingGateway` と同じ (30 秒ごとに推論し、長さで重み付けして平均する)。
final class SpeakerEmbedder {
    static let sampleRate = 16_000
    /// アプリの `ProvisionalParameters.speakerEmbeddingMinimumDuration`
    static let minimumDuration = 0.5
    private static let chunkDuration = 30.0

    private let model: MLModel

    init(packageURL: URL) async throws {
        let compiled = try await MLModel.compileModel(at: packageURL)
        model = try MLModel(contentsOf: compiled)
    }

    /// 音声が短すぎる場合は `nil`。
    func embedding(_ samples: [Float]) throws -> [Float]? {
        let minimumCount = Int(Self.minimumDuration * Double(Self.sampleRate))
        guard samples.count >= minimumCount else { return nil }

        let chunkCount = Int(Self.chunkDuration * Double(Self.sampleRate))
        var ranges: [Range<Int>] = []
        var start = 0
        while start < samples.count {
            let end = min(start + chunkCount, samples.count)
            ranges.append(start..<end)
            start = end
        }
        if ranges.count > 1, let last = ranges.last, last.count < minimumCount {
            ranges.removeLast()
            ranges[ranges.count - 1] = ranges[ranges.count - 1].lowerBound..<samples.count
        }

        var sum: [Float] = []
        for range in ranges {
            let chunk = normalized(try infer(Array(samples[range])))
            let weight = Float(range.count)
            if sum.isEmpty {
                sum = chunk.map { $0 * weight }
            } else {
                for index in sum.indices { sum[index] += chunk[index] * weight }
            }
        }
        return normalized(sum)
    }

    private func infer(_ samples: [Float]) throws -> [Float] {
        let input = try MLMultiArray(shape: [1, NSNumber(value: samples.count)], dataType: .float32)
        samples.withUnsafeBufferPointer { buffer in
            input.dataPointer.copyMemory(from: buffer.baseAddress!, byteCount: buffer.count * MemoryLayout<Float>.stride)
        }
        let output = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["waveform": input]))
        guard let embedding = output.featureValue(for: "embedding")?.multiArrayValue else {
            throw EmbedderError.invalidOutput
        }
        return (0..<embedding.count).map { embedding[$0].floatValue }
    }

    private func normalized(_ vector: [Float]) -> [Float] {
        let norm = vector.reduce(0) { $0 + $1 * $1 }.squareRoot()
        return norm > 0 ? vector.map { $0 / norm } : vector
    }
}

enum EmbedderError: Error {
    case invalidOutput
}

/// 分離された話者 1 人分の評価結果。
struct SpeakerReport {
    var id: String
    var duration: Double
    /// 本人の声とのコサイン類似度。発話が短すぎてベクトルを作れなかった場合は `nil`。
    var selfSimilarity: Float?
}

/// アプリの `ConversationAnalysisService` / `VectorMatchingService` と同じ規則で本人と相手を決める。
struct SelfIdentificationResult {
    var speakers: [SpeakerReport]
    /// 本人の声との類似度が最も高い話者。ベクトルを持つ話者がいなければ `nil`。
    var selfID: String?
    /// 本人以外でベクトルを持つ話者のうち、発話時間が最も長い話者。
    var partnerID: String?

    static func identify(
        segments: [LabeledSegment],
        audio: [Float],
        selfVector: [Float],
        embedder: SpeakerEmbedder
    ) throws -> SelfIdentificationResult {
        let rate = Double(SpeakerEmbedder.sampleRate)
        var speakers: [SpeakerReport] = []
        for (id, owned) in Dictionary(grouping: segments, by: \.speaker).sorted(by: { $0.key < $1.key }) {
            // 話者の区間をつなげてベクトルを作る (アプリと同じ)
            let samples = owned.flatMap { segment -> ArraySlice<Float> in
                let start = max(0, min(audio.count, Int(segment.start * rate)))
                let end = max(start, min(audio.count, Int(segment.end * rate)))
                return audio[start..<end]
            }
            let similarity = try embedder.embedding(samples).map { cosine($0, selfVector) }
            speakers.append(SpeakerReport(
                id: id, duration: owned.reduce(0) { $0 + $1.duration }, selfSimilarity: similarity
            ))
        }

        let selfID = speakers
            .filter { $0.selfSimilarity != nil }
            .max { $0.selfSimilarity! < $1.selfSimilarity! }?.id
        let partnerID = selfID.flatMap { selfID in
            speakers
                .filter { $0.id != selfID && $0.selfSimilarity != nil }
                .max { $0.duration < $1.duration }?.id
        }
        return SelfIdentificationResult(
            speakers: speakers, selfID: selfID, partnerID: partnerID
        )
    }

    private static func cosine(_ lhs: [Float], _ rhs: [Float]) -> Float {
        var dot: Float = 0
        var lhsNorm: Float = 0
        var rhsNorm: Float = 0
        for (l, r) in zip(lhs, rhs) {
            dot += l * r
            lhsNorm += l * l
            rhsNorm += r * r
        }
        return dot / (lhsNorm.squareRoot() * rhsNorm.squareRoot())
    }
}

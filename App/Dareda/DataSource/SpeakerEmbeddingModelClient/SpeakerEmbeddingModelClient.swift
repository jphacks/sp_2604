import CoreML
import Dependencies
import DependenciesMacros
import Foundation

/// ECAPA-TDNN (Core ML) による話者埋め込みの推論。
/// 入力は 16kHz モノラルの波形で、fbank 算出と平均正規化はモデルに含まれる。出力は正規化前の 192 次元ベクトル。
@DependencyClient
nonisolated struct SpeakerEmbeddingModelClient: Sendable {
    var embed: @Sendable (_ samples: [Float]) async throws -> [Float]
}

nonisolated extension SpeakerEmbeddingModelClient: DependencyKey {
    static let liveValue: SpeakerEmbeddingModelClient = {
        let impl = SpeakerEmbeddingModelClientImpl()
        return SpeakerEmbeddingModelClient(
            embed: impl.embed(_:)
        )
    }()

    static let previewValue = SpeakerEmbeddingModelClient.stub()
    static let testValue = SpeakerEmbeddingModelClient.stub()

    /// モデルを使わず、波形の統計量から決定的なベクトルを返すテストダブル。
    static func stub() -> SpeakerEmbeddingModelClient {
        SpeakerEmbeddingModelClient(
            embed: { samples in
                let count = max(samples.count, 1)
                let mean = samples.reduce(0, +) / Float(count)
                return (0..<192).map { mean + Float($0 + 1) }
            }
        )
    }
}

nonisolated extension DependencyValues {
    var speakerEmbeddingModelClient: SpeakerEmbeddingModelClient {
        get { self[SpeakerEmbeddingModelClient.self] }
        set { self[SpeakerEmbeddingModelClient.self] = newValue }
    }
}

nonisolated enum SpeakerEmbeddingModelError: Error, Equatable {
    case modelNotFound
    case invalidOutput
}

private nonisolated struct SpeakerEmbeddingModelClientImpl: Sendable {
    // MLModel は Sendable 準拠が宣言されていないが、読み込み後は変更しないため不変として扱う
    private nonisolated(unsafe) static let model = Result<MLModel, any Error> {
        guard let url = Bundle.main.url(forResource: "ECAPATDNN", withExtension: "mlmodelc") else {
            throw SpeakerEmbeddingModelError.modelNotFound
        }
        return try MLModel(contentsOf: url)
    }

    func embed(_ samples: [Float]) async throws -> [Float] {
        let model = try Self.model.get()
        let input = try MLMultiArray(shape: [1, NSNumber(value: samples.count)], dataType: .float32)
        samples.withUnsafeBufferPointer { buffer in
            input.dataPointer.copyMemory(from: buffer.baseAddress!, byteCount: buffer.count * MemoryLayout<Float>.stride)
        }
        let features = try MLDictionaryFeatureProvider(dictionary: ["waveform": input])
        let output = try await model.prediction(from: features)
        guard let embedding = output.featureValue(for: "embedding")?.multiArrayValue else {
            throw SpeakerEmbeddingModelError.invalidOutput
        }
        return (0..<embedding.count).map { embedding[$0].floatValue }
    }
}

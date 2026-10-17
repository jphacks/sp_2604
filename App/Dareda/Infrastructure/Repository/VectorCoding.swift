import Foundation

/// 声の特徴ベクトル (`[Float]`) と BLOB (`Data`) の相互変換。Repository 内でのみ使う。
nonisolated enum VectorCodingError: Error {
    case invalidByteCount(Int)
}

nonisolated extension Data {
    init(vector: [Float]) {
        self = vector.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    func vector() throws -> [Float] {
        let stride = MemoryLayout<Float>.stride
        guard count.isMultiple(of: stride) else {
            throw VectorCodingError.invalidByteCount(count)
        }
        return withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}

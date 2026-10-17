import Foundation

/// ユーザー本人の声の特徴ベクトル。本人識別 (第 1 段階) に使う。端末内に常に最大 1 件だけ保存される。
nonisolated struct SelfVoice: Sendable, Equatable {
    var vector: [Float]
    var createdAt: Date
}

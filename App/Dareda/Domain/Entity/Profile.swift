import Foundation

/// 会った相手のプロフィール。名前と所属は編集できる。
nonisolated struct Profile: Sendable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var affiliation: String
    /// 相手の声の特徴ベクトル。人物検索 (第 2 段階) の照合に使う。
    var vector: [Float]
}

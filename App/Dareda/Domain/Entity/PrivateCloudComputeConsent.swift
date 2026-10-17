import Foundation

/// 会話要約で Private Cloud Compute を使うことへのユーザーの同意状態。
nonisolated enum PrivateCloudComputeConsent: String, Sendable, Equatable {
    /// まだ選択していない。最初のコンテキスト超過時に確認する。
    case undetermined
    /// 許可した。端末内のコンテキスト量を超えた場合のみ PCC を使う。
    case granted
    /// 拒否した。常に端末内で分割して要約する。
    case denied
}

import Foundation

/// 録音から人物検索の結果までの Live Activity に表示する内容。
nonisolated enum RecordingActivity: Sendable, Equatable {
    case recording(startedAt: Date)
    /// 解析中。引数は処理中の段階の表示名。
    case analyzing(stage: String)
    /// 人物検索で最も声が近い 1 人。
    case candidate(Profile, Encounter?)
    /// 相手の発話が足りず、アプリで追加録音が必要。
    case needsAdditionalRecording
    /// 本人を自動判定できず、アプリで選ぶ必要がある。
    case needsSelfSelection
    /// 登録済みの人物がいない。
    case noCandidate
    /// 解析に失敗した。アプリで再試行できる。
    case failed
}

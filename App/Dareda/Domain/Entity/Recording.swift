import Foundation

/// 1 回の会話録音。
nonisolated struct Recording: Sendable, Equatable, Identifiable {
    let id: UUID
    /// 録音ファイルの場所。
    let fileURL: URL
    /// 録音を開始した時刻。新規登録時の「会った日時」の初期値になる。
    let startedAt: Date
    /// 録音済みの長さ (秒)。録音中は 0、停止・中断後に確定した値が入る。
    var duration: TimeInterval
}

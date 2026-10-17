import Foundation

/// 録音から保存・照合完了までの 1 回の処理を表すセッション。
/// 音声・文字起こし・一時ベクトルなどの一時データは `directoryURL` 以下に置く。
nonisolated struct ProcessingSession: Sendable, Equatable, Identifiable {
    let id: UUID
    let directoryURL: URL
}

import Foundation

/// バックグラウンドで処理を続けるために確保した実行時間。終了時に同じ値を渡す。
nonisolated struct BackgroundExecution: Sendable, Equatable, Identifiable {
    let id: Int
}

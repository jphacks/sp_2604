import ActivityKit
import Foundation

/// 録音から人物検索の結果までを表示する Live Activity。アプリと Widget Extension の両方でビルドする。
nonisolated struct RecordingActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        var phase: Phase
    }

    nonisolated enum Phase: Codable, Hashable, Sendable {
        /// 録音中。経過時間は `startedAt` からシステムが数える。
        case recording(startedAt: Date)
        /// 音声の解析中。
        case analyzing(stage: String)
        /// 人物検索の結果 (最も声が近い 1 人)。
        case candidate(Candidate)
        /// アプリでの操作が必要、または結果を出せなかったときの案内。
        case message(String)
    }

    nonisolated struct Candidate: Codable, Hashable, Sendable {
        var name: String
        var affiliation: String
        var metAt: Date?
        var placeName: String?
        var summary: String?
    }
}

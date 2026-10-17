import Foundation

/// iPhone と Apple Watch の間でやり取りする内容。iPhone が母艦としてデータと処理を持ち、
/// Apple Watch は表示・操作と録音だけを担う。
///
/// - iPhone → Watch: `WatchSnapshot` を Application Context で送る (最新の状態だけが届けばよい)。
/// - Watch → iPhone: 録音ファイルは `transferFile`、操作は `WatchCommand` をメッセージで送る。
nonisolated enum WatchSyncKey {
    /// Application Context に入れる `WatchSnapshot` (JSON)。
    static let snapshot = "snapshot"
    /// メッセージに入れる `WatchCommand` (JSON)。
    static let command = "command"
    /// 録音ファイルのメタデータに入れる、録音を開始した時刻 (`timeIntervalSince1970`)。
    static let startedAt = "startedAt"
    /// 録音ファイルのメタデータに入れる、人物検索の追加録音かどうか (`Bool`)。
    static let isAdditional = "isAdditional"
}

/// iPhone の状態を Apple Watch に表示するためのスナップショット。
nonisolated struct WatchSnapshot: Codable, Sendable, Equatable {
    var profiles: [WatchProfile]
    /// 録音・解析できる状態か (Apple Intelligence の利用可否や本人の声の登録状況)。
    var isRecordingAvailable: Bool
    /// iPhone で処理中の録音の状況。処理していなければ `nil`。
    var processing: WatchProcessingState?

    static let empty = WatchSnapshot(profiles: [], isRecordingAvailable: false, processing: nil)
}

nonisolated struct WatchProfile: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var affiliation: String
    var summary: String?
    var metAt: Date?
    var placeName: String?
}

nonisolated enum WatchProcessingState: Codable, Sendable, Equatable {
    /// 文字起こし・話者の識別・要約のいずれかを実行中。
    case processing(WatchProcessingStage)
    /// 人物検索の候補 (類似度の高い順)。Apple Watch からも確定できる。
    case candidates([WatchProfile])
    /// 相手の発話が足りないため、追加録音が必要。
    case needsAdditionalRecording
    /// 本人の選択や新規登録の入力など、iPhone での操作が必要。
    case needsInputOnPhone
    case failed(message: String)
    /// 人物を確定した、または新規登録した。
    case completed(WatchProfile?)
}

nonisolated enum WatchProcessingStage: String, Codable, Sendable, Equatable {
    case transcribing
    case identifyingSpeakers
    case summarizing
}

/// Apple Watch から iPhone への操作。
nonisolated enum WatchCommand: Codable, Sendable, Equatable {
    /// 人物検索の候補を確定する。
    case selectCandidate(UUID)
    /// 処理中の録音をキャンセルする。
    case cancelProcessing
    /// 最新のスナップショットを求める。
    case requestSnapshot
}

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
    /// 録音ファイルのメタデータに入れる、録音の用途 (`WatchRecordingKind` の rawValue)。
    static let kind = "kind"
}

/// Apple Watch で録音した音声の用途。
nonisolated enum WatchRecordingKind: String, Codable, Sendable {
    /// 会話の録音。人物検索から始める。
    case conversation
    /// 人物検索で相手の発話が足りないときの追加録音。
    case additional
    /// 本人の声の登録・再登録。
    case selfVoice
}

/// iPhone の状態を Apple Watch に表示するためのスナップショット。
nonisolated struct WatchSnapshot: Codable, Sendable, Equatable {
    var profiles: [WatchProfile]
    /// 録音・解析できる状態か (Apple Intelligence の利用可否や本人の声の登録状況)。
    var isRecordingAvailable: Bool
    /// iPhone で処理中の録音の状況。処理していなければ `nil`。
    var processing: WatchProcessingState?
    var settings: WatchSettings = WatchSettings()

    static let empty = WatchSnapshot(profiles: [], isRecordingAvailable: false, processing: nil)
}

/// 設定画面と本人の声の登録に使う状態。
nonisolated struct WatchSettings: Codable, Sendable, Equatable {
    /// 本人の声を登録した日時。未登録なら `nil`。
    var selfVoiceRegisteredAt: Date?
    var selfVoiceEnrollment: WatchSelfVoiceEnrollmentState?
    var isPrivateCloudComputeEnabled = false
    var appVersion: String?
}

nonisolated enum WatchSelfVoiceEnrollmentState: Codable, Sendable, Equatable {
    case processing
    case completed
    case failed(message: String)
}

nonisolated struct WatchSpeaker: Codable, Sendable, Equatable, Identifiable {
    var id: String
    /// この話者の発言 (発話順)。本人かどうかを見分けるために表示する。
    var speeches: [String]
}

nonisolated struct WatchPlace: Codable, Sendable, Hashable {
    var name: String
    var latitude: Double
    var longitude: Double
}

/// 新規登録の入力の初期値。
nonisolated struct WatchRegistrationDraft: Codable, Sendable, Equatable {
    var summary: String
    var metAt: Date
    /// Apple Watch で入力した場所の検索結果。
    var placeCandidates: [WatchPlace]
    /// 保存に失敗したときのメッセージ。
    var errorMessage: String?
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
    /// 本人を自動判定できなかった。話者ごとの発言から本人を選ぶ。
    case selectSelf([WatchSpeaker])
    /// 新規登録の入力待ち。
    case registration(WatchRegistrationDraft)
    /// バックグラウンドで打ち切られた処理の再開など、iPhone での操作が必要。
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
    /// 失敗した処理を再試行する。
    case retryProcessing
    /// 本人の話者を選ぶ。
    case selectSelf(String)
    /// 人物検索で「該当なし」を選び、新規登録に進む。
    case startNewRegistration
    /// 新規登録の場所を検索する。
    case searchPlaces(String)
    /// 新規登録を保存する。
    case register(name: String, affiliation: String, summary: String, place: WatchPlace?)
    case setPrivateCloudComputeEnabled(Bool)
    /// 最新のスナップショットを求める。
    case requestSnapshot
}

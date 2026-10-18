import Foundation

/// 前回の会話の記録。プロフィールごとに 1 件だけ持ち、新規登録時に作られる。編集や人物検索の上書きで置き換える。
nonisolated struct Encounter: Sendable, Equatable, Identifiable {
    var id: UUID
    var profileID: Profile.ID
    var summary: String
    var metAt: Date
    var place: Place?
}

/// 会った場所 (任意)。MapKit の検索結果から選択する。
nonisolated struct Place: Sendable, Hashable {
    var name: String
    var latitude: Double
    var longitude: Double
}

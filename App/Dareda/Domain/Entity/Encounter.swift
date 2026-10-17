import Foundation

/// 初回の出会い記録。プロフィールの新規登録時に 1 件だけ作られ、以後は追加・更新しない。
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

import Foundation

/// プロフィールと、その前回の会話の記録をまとめた値。
nonisolated struct ProfileDetailServiceModel: Sendable, Equatable {
    var profile: Profile
    var encounter: Encounter?
}

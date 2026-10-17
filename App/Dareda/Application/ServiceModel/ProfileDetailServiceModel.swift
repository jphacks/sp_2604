import Foundation

/// プロフィールと、その初回の出会い記録をまとめた値。
nonisolated struct ProfileDetailServiceModel: Sendable, Equatable {
    var profile: Profile
    var encounter: Encounter?
}

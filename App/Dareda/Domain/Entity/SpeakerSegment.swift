import Foundation

/// 話者分離で得られた、ある話者の発話区間。
/// この段階では話者が本人か相手かは確定していないため、`speakerID` は分離結果内でのみ意味を持つ。
nonisolated struct SpeakerSegment: Sendable, Equatable, Identifiable, Codable {
    let speakerID: String
    let startTime: TimeInterval
    let endTime: TimeInterval

    var id: String { "\(speakerID)-\(startTime)" }

    var duration: TimeInterval { endTime - startTime }
}

import Foundation

/// マイクの利用権限。
nonisolated enum RecordingPermission: Sendable, Equatable {
    case undetermined
    case granted
    case denied
}

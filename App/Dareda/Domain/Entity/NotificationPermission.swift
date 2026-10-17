import Foundation

/// 通知の許可状態。
nonisolated enum NotificationPermission: Sendable, Equatable {
    case undetermined
    case granted
    case denied
}

import Foundation

/// App Intent (Live Activity・コントロール・ショートカット) からアプリへの操作の依頼。
nonisolated enum AppIntentRequest: String, Sendable, Equatable {
    case startRecording
    case stopRecording
}

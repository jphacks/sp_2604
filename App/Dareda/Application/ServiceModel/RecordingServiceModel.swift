import Foundation

/// 録音中に発生するイベント。
nonisolated enum RecordingEvent: Sendable, Equatable {
    case elapsedTimeChanged(TimeInterval)
    /// 上限まで残り 1 分 (`RecordingConfiguration.warningRemaining`) になった。
    case oneMinuteRemaining
    /// 上限に達したため自動停止した。録音済みの内容が確定した `Recording` を持つ。
    case limitReached(Recording)
    /// 電話などで中断された。自動再開はせず、録音済み部分を `Recording` として保持する。
    case interrupted(Recording)
}

/// 録音の設定値。上限は暫定値のため外出ししている。
nonisolated struct RecordingConfiguration: Sendable, Equatable {
    /// 1 回の録音の上限 (暫定 10 分)。
    var maxDuration: TimeInterval
    /// 上限のどれだけ前に `oneMinuteRemaining` を通知するか (1 分)。
    var warningRemaining: TimeInterval

    static let `default` = RecordingConfiguration(maxDuration: 10 * 60, warningRemaining: 60)
}

nonisolated enum RecordingError: Error, Sendable, Equatable {
    /// マイク権限が拒否されている。設定アプリへの案内が必要。
    case permissionDenied
}

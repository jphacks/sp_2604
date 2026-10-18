import AppIntents
#if !WIDGET_EXTENSION
    import Dependencies
#endif

// アプリと Widget Extension の両方でビルドする。Widget Extension から実行されても、
// `allowedExecutionTargets` によりアプリのプロセスで `perform()` が呼ばれる。
// AppIntents にも `Dependency` があるため、swift-dependencies のものはモジュール名を付けて使う。

/// アプリを開いてマイクから録音を始める。
struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "録音を開始"
    static let description = IntentDescription("Dareda を開いて会話の録音を始めます。")
    static var supportedModes: IntentModes { .foreground(.immediate) }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
            let appIntentRequestService = Dependencies.Dependency(\.appIntentRequestService).wrappedValue
            appIntentRequestService.send(.startRecording)
        #endif
        return .result()
    }
}

/// 録音を止め、アプリを開いて音声の解析を始める。
struct StopRecordingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "録音を終了"
    static let description = IntentDescription("録音を終了し、Dareda を開いて相手の判定を始めます。")
    static var supportedModes: IntentModes { .foreground(.immediate) }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
            let appIntentRequestService = Dependencies.Dependency(\.appIntentRequestService).wrappedValue
            appIntentRequestService.send(.stopRecording)
        #endif
        return .result()
    }
}

/// 録音・解析結果の Live Activity を閉じる。
struct DismissRecordingActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Live Activity を閉じる"
    static let description = IntentDescription("録音・人物検索の結果の Live Activity を閉じます。")
    static var supportedModes: IntentModes { .background }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
            let recordingActivityService = Dependencies.Dependency(\.recordingActivityService).wrappedValue
            await recordingActivityService.end()
        #endif
        return .result()
    }
}

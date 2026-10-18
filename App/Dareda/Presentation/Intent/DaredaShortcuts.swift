import AppIntents

/// Siri・Spotlight・ショートカットアプリから使える操作。
struct DaredaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "\(.applicationName)で録音を開始",
                "\(.applicationName)で録音して",
            ],
            shortTitle: "録音を開始",
            systemImageName: "mic.fill"
        )
    }
}

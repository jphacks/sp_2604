import SwiftUI

@main
struct DaredaWatchApp: App {
    @State private var phoneSession = PhoneSession()
    @State private var recorder = WatchRecorder()

    var body: some Scene {
        WindowGroup {
            HomeScreen()
                .environment(phoneSession)
                .environment(recorder)
                .onAppear { phoneSession.activate() }
        }
    }
}

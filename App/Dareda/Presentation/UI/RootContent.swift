import SwiftUI

struct RootContent: View {
    let isRequestingPermission: Bool
    let alert: RootViewModel.Alert?
    let availability: DeviceAvailability?
    let isSettingsPresented: Bool
    let isRecordingPresented: Bool
    let isVoiceEnrollmentPresented: Bool
    let isPreparedForRecording: Bool
    var registeredProfileID: Profile.ID?
    let send: (RootViewModel.Action) -> Void

    var body: some View {
        ProfileListScreen(registeredProfileID: registeredProfileID) {
            EmptyView()
        } actions: {
            // 録音・解析は利用可否が `available` のときのみ有効にする。
            Button { send(.recordButtonTapped) } label: {
                Label("録音", systemImage: "mic")
            }
            .disabled(
                availability?.isAvailable != true || !isPreparedForRecording || isRequestingPermission
            )
            .accessibilityIdentifier("root.recordButton")

            // 設定は利用可否にかかわらず変更可能にする。
            Button { send(.settingsMenuButtonTapped) } label: {
                Label("設定", systemImage: "gearshape")
            }
            .accessibilityIdentifier("root.settingsButton")
        }
        .fullScreenCover(isPresented: Binding(
            get: { isRecordingPresented },
            set: { if !$0 { send(.recordingFinished(nil)) } }
        )) {
            RecordingScreen { send(.recordingFinished($0)) }
        }
        // 登録が済むまで閉じられないよう、完了時のみ閉じる
        .fullScreenCover(isPresented: .constant(isVoiceEnrollmentPresented)) {
            VoiceEnrollmentScreen { send(.voiceEnrollmentCompleted) }
        }
        .sheet(
            isPresented: Binding(
                get: { isSettingsPresented },
                set: { send(.settingsPresentedChanged($0)) }
            )
        ) {
            SettingsScreen()
        }
        .alert(
            "マイクの使用が許可されていません",
            isPresented: Binding(
                get: { alert == .microphoneDenied },
                set: { if !$0 { send(.alertDismissed) } }
            )
        ) {
            Button("設定を開く") { send(.settingsButtonTapped) }
                .accessibilityIdentifier("root.openSettingsButton")
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("録音するには、設定アプリでDaredaのマイクを許可してください。")
        }
        .alert(
            "前回の録音を整理できませんでした",
            isPresented: Binding(
                get: { alert == .preparationFailed },
                set: { if !$0 { send(.alertDismissed) } }
            )
        ) {
            Button("再試行") { send(.preparationRetryButtonTapped) }
                .accessibilityIdentifier("root.preparationRetryButton")
        } message: {
            Text("再試行してください。")
        }
    }
}

#Preview("利用可") {
    RootContent(
        isRequestingPermission: false,
        alert: nil,
        availability: .available,
        isSettingsPresented: false,
        isRecordingPresented: false,
        isVoiceEnrollmentPresented: false,
        isPreparedForRecording: true,
        send: { _ in }
    )
}

#Preview("非対応") {
    RootContent(
        isRequestingPermission: false,
        alert: nil,
        availability: .unsupported,
        isSettingsPresented: false,
        isRecordingPresented: false,
        isVoiceEnrollmentPresented: false,
        isPreparedForRecording: true,
        send: { _ in }
    )
}

#Preview("一時的に利用不可") {
    RootContent(
        isRequestingPermission: false,
        alert: nil,
        availability: .temporarilyUnavailable(.modelNotReady),
        isSettingsPresented: false,
        isRecordingPresented: false,
        isVoiceEnrollmentPresented: false,
        isPreparedForRecording: true,
        send: { _ in }
    )
}

#Preview("マイク拒否") {
    RootContent(
        isRequestingPermission: false,
        alert: .microphoneDenied,
        availability: .available,
        isSettingsPresented: false,
        isRecordingPresented: false,
        isVoiceEnrollmentPresented: false,
        isPreparedForRecording: true,
        send: { _ in }
    )
}

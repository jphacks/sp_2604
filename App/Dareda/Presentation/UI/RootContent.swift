import SwiftUI

struct RootContent: View {
    let recordingPermission: RecordingPermission?
    let isRequestingPermission: Bool
    let settingsErrorMessage: String?
    let availability: DeviceAvailability?
    let isPrivateCloudComputeSettingsPresented: Bool
    let isSettingsPresented: Bool
    let isRecordingPresented: Bool
    let isVoiceEnrollmentPresented: Bool
    let isPreparedForRecording: Bool
    let preparationErrorMessage: LocalizedStringResource?
    let send: (RootViewModel.Action) -> Void

    var body: some View {
        ProfileListScreen {
            notices
        } actions: {
            // 録音・解析は利用可否が `available` のときのみ有効にする。
            Button { send(.recordButtonTapped) } label: {
                Label("録音", systemImage: "mic")
            }
            .disabled(
                availability?.isAvailable != true || !isPreparedForRecording || isRequestingPermission
            )
            .accessibilityIdentifier("root.recordButton")

            // 要約の設定は利用可否にかかわらず変更可能にする。
            Button { send(.privateCloudComputeSettingsButtonTapped) } label: {
                Label("要約の設定", systemImage: "gearshape")
            }
            .accessibilityIdentifier("root.privateCloudComputeSettingsButton")

            // 本人の声の再登録は利用可否にかかわらず可能にする。
            Button { send(.settingsMenuButtonTapped) } label: {
                Label("設定", systemImage: "person.wave.2")
            }
            .accessibilityIdentifier("root.settingsButton")
        }
        .fullScreenCover(isPresented: Binding(
            get: { isRecordingPresented },
            set: { if !$0 { send(.recordingFinished) } }
        )) {
            RecordingScreen { send(.recordingFinished) }
        }
        // 登録が済むまで閉じられないよう、完了時のみ閉じる
        .fullScreenCover(isPresented: .constant(isVoiceEnrollmentPresented)) {
            VoiceEnrollmentScreen { send(.voiceEnrollmentCompleted) }
        }
        .sheet(
            isPresented: Binding(
                get: { isPrivateCloudComputeSettingsPresented },
                set: { send(.privateCloudComputeSettingsPresentedChanged($0)) }
            )
        ) {
            PrivateCloudComputeSettingsScreen()
        }
        .sheet(
            isPresented: Binding(
                get: { isSettingsPresented },
                set: { send(.settingsPresentedChanged($0)) }
            )
        ) {
            SettingsScreen()
        }
    }

    @ViewBuilder
    private var notices: some View {
        VStack(spacing: 12) {
            if let availability, !availability.isAvailable {
                AvailabilityNotice(availability: availability) {
                    send(.recheckButtonTapped)
                }
            }

            if let preparationErrorMessage {
                Text(preparationErrorMessage)
                    .accessibilityIdentifier("root.preparationErrorNotice")
                Button("再試行") { send(.preparationRetryButtonTapped) }
                    .accessibilityIdentifier("root.preparationRetryButton")
            }

            if recordingPermission == .denied {
                Text("マイクの使用が許可されていません。設定アプリでDaredaのマイクを許可し、戻ってからもう一度録音ボタンを押してください。")
                    .accessibilityIdentifier("root.microphoneDeniedNotice")
                Button("設定アプリを開く") { send(.settingsButtonTapped) }
                    .accessibilityIdentifier("root.openSettingsButton")
            } else if recordingPermission == .granted {
                Text("マイクの使用が許可されました")
                    .accessibilityIdentifier("root.microphoneGrantedNotice")
            }

            if let settingsErrorMessage {
                Text(settingsErrorMessage)
                    .accessibilityIdentifier("root.settingsErrorNotice")
            }
        }
        .padding(.horizontal)
    }
}

#Preview("利用可") {
    RootContent(
        recordingPermission: nil,
        isRequestingPermission: false,
        settingsErrorMessage: nil,
        availability: .available,
        isPrivateCloudComputeSettingsPresented: false,
        isSettingsPresented: false,
        isRecordingPresented: false,
        isVoiceEnrollmentPresented: false,
        isPreparedForRecording: true,
        preparationErrorMessage: nil,
        send: { _ in }
    )
}

#Preview("非対応") {
    RootContent(
        recordingPermission: nil,
        isRequestingPermission: false,
        settingsErrorMessage: nil,
        availability: .unsupported,
        isPrivateCloudComputeSettingsPresented: false,
        isSettingsPresented: false,
        isRecordingPresented: false,
        isVoiceEnrollmentPresented: false,
        isPreparedForRecording: true,
        preparationErrorMessage: nil,
        send: { _ in }
    )
}

#Preview("一時的に利用不可") {
    RootContent(
        recordingPermission: nil,
        isRequestingPermission: false,
        settingsErrorMessage: nil,
        availability: .temporarilyUnavailable(.modelNotReady),
        isPrivateCloudComputeSettingsPresented: false,
        isSettingsPresented: false,
        isRecordingPresented: false,
        isVoiceEnrollmentPresented: false,
        isPreparedForRecording: true,
        preparationErrorMessage: nil,
        send: { _ in }
    )
}

#Preview("マイク拒否") {
    RootContent(
        recordingPermission: .denied,
        isRequestingPermission: false,
        settingsErrorMessage: nil,
        availability: .available,
        isPrivateCloudComputeSettingsPresented: false,
        isSettingsPresented: false,
        isRecordingPresented: false,
        isVoiceEnrollmentPresented: false,
        isPreparedForRecording: true,
        preparationErrorMessage: nil,
        send: { _ in }
    )
}

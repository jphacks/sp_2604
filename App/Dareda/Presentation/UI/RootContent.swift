import SwiftUI

struct RootContent: View {
    let recordingPermission: RecordingPermission?
    let isRequestingPermission: Bool
    let settingsErrorMessage: String?
    let availability: DeviceAvailability?
    let isProfileListPresented: Bool
    let isRecordingPresented: Bool
    let isVoiceEnrollmentPresented: Bool
    let isPreparedForRecording: Bool
    let preparationErrorMessage: LocalizedStringResource?
    let send: (RootViewModel.Action) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Dareda")
                .font(.largeTitle)
                .accessibilityIdentifier("root.title")

            if let availability {
                if !availability.isAvailable {
                    AvailabilityNotice(availability: availability) {
                        send(.recheckButtonTapped)
                    }
                }

                // 録音・解析は利用可否が `available` のときのみ有効にする。
                Button("録音") { send(.recordButtonTapped) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!availability.isAvailable || !isPreparedForRecording || isRequestingPermission)
                    .accessibilityIdentifier("root.recordButton")

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

                // 保存済みプロフィールの閲覧は利用可否にかかわらず可能にする。
                Button("プロフィール") { send(.profilesButtonTapped) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("root.profilesButton")
            }
        }
        .padding()
        .fullScreenCover(isPresented: Binding(
            get: { isRecordingPresented },
            set: { if !$0 { send(.recordingFinished) } }
        )) {
            RecordingScreen { send(.recordingFinished) }
        }
        .sheet(
            isPresented: Binding(
                get: { isProfileListPresented },
                set: { send(.profileListPresentedChanged($0)) }
            )
        ) {
            ProfileListScreen()
        }
        // 登録が済むまで閉じられないよう、完了時のみ閉じる
        .fullScreenCover(isPresented: .constant(isVoiceEnrollmentPresented)) {
            VoiceEnrollmentScreen { send(.voiceEnrollmentCompleted) }
        }
    }
}

#Preview("利用可") {
    RootContent(
        recordingPermission: nil,
        isRequestingPermission: false,
        settingsErrorMessage: nil,
        availability: .available,
        isProfileListPresented: false,
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
        isProfileListPresented: false,
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
        isProfileListPresented: false,
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
        isProfileListPresented: false,
        isRecordingPresented: false,
        isVoiceEnrollmentPresented: false,
        isPreparedForRecording: true,
        preparationErrorMessage: nil,
        send: { _ in }
    )
}

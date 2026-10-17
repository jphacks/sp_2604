import SwiftUI

struct RootContent: View {
    let recordingPermission: RecordingPermission?
    let isRequestingPermission: Bool
    let settingsErrorMessage: String?
    let availability: DeviceAvailability?
    let isProfileListPresented: Bool
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
                    .disabled(!availability.isAvailable || isRequestingPermission)
                    .accessibilityIdentifier("root.recordButton")

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
        .sheet(
            isPresented: Binding(
                get: { isProfileListPresented },
                set: { send(.profileListPresentedChanged($0)) }
            )
        ) {
            ProfileListScreen()
        }
    }
}

#Preview("利用可") {
    RootContent(recordingPermission: nil, isRequestingPermission: false, settingsErrorMessage: nil, availability: .available, isProfileListPresented: false, send: { _ in })
}

#Preview("非対応") {
    RootContent(recordingPermission: nil, isRequestingPermission: false, settingsErrorMessage: nil, availability: .unsupported, isProfileListPresented: false, send: { _ in })
}

#Preview("一時的に利用不可") {
    RootContent(recordingPermission: nil, isRequestingPermission: false, settingsErrorMessage: nil, availability: .temporarilyUnavailable(.modelNotReady), isProfileListPresented: false, send: { _ in })
}

#Preview("マイク拒否") {
    RootContent(recordingPermission: .denied, isRequestingPermission: false, settingsErrorMessage: nil, availability: .available, isProfileListPresented: false, send: { _ in })
}

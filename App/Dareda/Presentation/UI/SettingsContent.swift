import SwiftUI

struct SettingsContent: View {
    let selfVoiceRegisteredAt: Date?
    let isVoiceReregistrationPresented: Bool
    let privateCloudComputeConsent: PrivateCloudComputeConsent
    var recordingPermission: RecordingPermission?
    var notificationPermission: NotificationPermission?
    var appVersion: AppVersion?
    let send: (SettingsViewModel.Action) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("登録日時") {
                        Text(selfVoiceRegisteredAt?.formatted(date: .numeric, time: .shortened) ?? "-")
                            .accessibilityIdentifier("settings.selfVoiceRegisteredAt")
                    }
                    Button("声を再登録") { send(.reregisterVoiceButtonTapped) }
                        .accessibilityIdentifier("settings.reregisterVoiceButton")
                } header: {
                    Text("本人の声")
                } footer: {
                    Text("会話の中であなたの声を見分けられないときは、声を登録し直してください。新しい声の登録が完了するまで、今の登録は残ります。")
                }

                Section {
                    Toggle(
                        "Private Cloud Computeを使う",
                        isOn: Binding(
                            get: { privateCloudComputeConsent == .granted },
                            set: { send(.isPrivateCloudComputeEnabledChanged($0)) }
                        )
                    )
                    .accessibilityIdentifier("settings.privateCloudComputeToggle")
                } header: {
                    Text("要約")
                } footer: {
                    Text("会話が長く端末内で要約しきれない場合に限り、文字起こし全文（話者ラベル付き）と要約の指示をAppleのPrivate Cloud Computeへ送って要約します。音声・声の特徴・保存したプロフィール・位置情報は送信しません。オフにすると、端末内で分割して要約します。")
                }

                Section {
                    Button { send(.permissionRowTapped) } label: {
                        LabeledContent("マイク") { Text(Self.label(recordingPermission)) }
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("settings.microphonePermission")
                    Button { send(.permissionRowTapped) } label: {
                        LabeledContent("プッシュ通知") { Text(Self.label(notificationPermission)) }
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("settings.notificationPermission")
                } header: {
                    Text("権限")
                } footer: {
                    Text("タップすると設定アプリが開き、許可を変更できます。")
                }

                Section("アプリ情報") {
                    LabeledContent("バージョン") {
                        Text(appVersion.map { "\($0.version) (\($0.build))" } ?? "-")
                            .accessibilityIdentifier("settings.appVersion")
                    }
                }
            }
            .navigationTitle("設定")
        }
        // 登録に失敗しても今の登録が残るよう、完了かキャンセルでのみ閉じる
        .fullScreenCover(isPresented: .constant(isVoiceReregistrationPresented)) {
            VoiceEnrollmentScreen(
                onCompleted: { send(.voiceReregistrationFinished) },
                onCancelled: { send(.voiceReregistrationFinished) }
            )
        }
    }

    private static func label(_ permission: RecordingPermission?) -> LocalizedStringResource {
        switch permission {
        case .granted: "許可"
        case .denied: "未許可"
        case .undetermined: "未設定"
        case nil: "-"
        }
    }

    private static func label(_ permission: NotificationPermission?) -> LocalizedStringResource {
        switch permission {
        case .granted: "許可"
        case .denied: "未許可"
        case .undetermined: "未設定"
        case nil: "-"
        }
    }
}

#Preview("登録済み") {
    SettingsContent(
        selfVoiceRegisteredAt: Date(timeIntervalSince1970: 1_790_000_000),
        isVoiceReregistrationPresented: false,
        privateCloudComputeConsent: .undetermined,
        send: { _ in }
    )
}

#Preview("PCC 許可") {
    SettingsContent(
        selfVoiceRegisteredAt: Date(timeIntervalSince1970: 1_790_000_000),
        isVoiceReregistrationPresented: false,
        privateCloudComputeConsent: .granted,
        recordingPermission: .granted,
        notificationPermission: .denied,
        appVersion: AppVersion(version: "1.0.0", build: "42"),
        send: { _ in }
    )
}

import SwiftUI

struct SettingsContent: View {
    let selfVoiceRegisteredAt: Date?
    let isVoiceReregistrationPresented: Bool
    let privateCloudComputeConsent: PrivateCloudComputeConsent
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
        send: { _ in }
    )
}

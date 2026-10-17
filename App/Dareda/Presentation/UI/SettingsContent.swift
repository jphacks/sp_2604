import SwiftUI

struct SettingsContent: View {
    let selfVoiceRegisteredAt: Date?
    let isVoiceReregistrationPresented: Bool
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
        send: { _ in }
    )
}

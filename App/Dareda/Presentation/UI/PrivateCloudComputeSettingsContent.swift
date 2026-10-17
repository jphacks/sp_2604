import SwiftUI

struct PrivateCloudComputeSettingsContent: View {
    let consent: PrivateCloudComputeConsent
    let send: (PrivateCloudComputeSettingsViewModel.Action) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        "Private Cloud Computeを使う",
                        isOn: Binding(get: { consent == .granted }, set: { send(.isEnabledChanged($0)) })
                    )
                    .accessibilityIdentifier("privateCloudComputeSettings.toggle")
                } footer: {
                    Text("会話が長く端末内で要約しきれない場合に限り、文字起こし全文（話者ラベル付き）と要約の指示をAppleのPrivate Cloud Computeへ送って要約します。音声・声の特徴・保存したプロフィール・位置情報は送信しません。オフにすると、端末内で分割して要約します。")
                }
            }
            .navigationTitle("要約の設定")
        }
    }
}

#Preview("未選択") {
    PrivateCloudComputeSettingsContent(consent: .undetermined, send: { _ in })
}

#Preview("許可") {
    PrivateCloudComputeSettingsContent(consent: .granted, send: { _ in })
}

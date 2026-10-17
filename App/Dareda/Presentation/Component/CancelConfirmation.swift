import SwiftUI

/// 誤操作を防ぐため、キャンセル・破棄の前に表示する確認。
/// ボタンの accessibilityIdentifier は `<identifierPrefix>.confirmDiscardButton` / `<identifierPrefix>.cancelDiscardButton`。
struct CancelConfirmation: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let confirmTitle: LocalizedStringResource
    let keepTitle: LocalizedStringResource
    let identifierPrefix: String
    let onConfirm: () -> Void
    let onKeep: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(title).font(.title2.bold())
            Text(message)
                .multilineTextAlignment(.center)
            Button(role: .destructive, action: onConfirm) { Text(confirmTitle) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("\(identifierPrefix).confirmDiscardButton")
            Button(role: .cancel, action: onKeep) { Text(keepTitle) }
                .accessibilityIdentifier("\(identifierPrefix).cancelDiscardButton")
        }
        .padding()
    }
}

#Preview {
    CancelConfirmation(
        title: "処理をキャンセルしますか？",
        message: "録音と処理中のデータは削除されます。",
        confirmTitle: "キャンセルする",
        keepTitle: "続ける",
        identifierPrefix: "preview",
        onConfirm: {},
        onKeep: {}
    )
}

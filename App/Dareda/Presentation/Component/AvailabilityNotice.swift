import SwiftUI

struct AvailabilityNotice: View {
    let availability: DeviceAvailability
    let onRecheck: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .accessibilityIdentifier("root.availabilityTitle")
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("root.availabilityMessage")
            Button("再判定", action: onRecheck)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("root.recheckButton")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("root.availabilityNotice.\(identifier)")
    }

    private var identifier: String {
        switch availability {
        case .available: "available"
        case .unsupported: "unsupported"
        case .temporarilyUnavailable: "temporarilyUnavailable"
        }
    }

    private var title: String {
        switch availability {
        case .available:
            ""
        case .unsupported:
            "この端末には対応していません"
        case .temporarilyUnavailable:
            "現在は利用できません"
        }
    }

    private var message: String {
        switch availability {
        case .available:
            ""
        case .unsupported:
            "Apple Intelligence に対応した iPhone が必要です。録音・解析は利用できませんが、保存済みのプロフィールは閲覧できます。"
        case .temporarilyUnavailable(.appleIntelligenceDisabled):
            "設定アプリで Apple Intelligence を有効にしてから、再判定してください。"
        case .temporarilyUnavailable(.modelNotReady):
            "モデルを準備中です。しばらく待ってから、再判定してください。"
        case .temporarilyUnavailable(.unknown):
            "しばらく待ってから、再判定してください。"
        }
    }
}

#Preview {
    AvailabilityNotice(availability: .unsupported, onRecheck: {})
}

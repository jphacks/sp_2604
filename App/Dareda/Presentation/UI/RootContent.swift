import SwiftUI

struct RootContent: View {
    let availability: DeviceAvailability?
    let isProfileListPresented: Bool
    let isVoiceEnrollmentPresented: Bool
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
                Button("録音") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(!availability.isAvailable)
                    .accessibilityIdentifier("root.recordButton")

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
        // 登録が済むまで閉じられないよう、完了時のみ閉じる
        .fullScreenCover(isPresented: .constant(isVoiceEnrollmentPresented)) {
            VoiceEnrollmentScreen { send(.voiceEnrollmentCompleted) }
        }
    }
}

#Preview("利用可") {
    RootContent(availability: .available, isProfileListPresented: false, isVoiceEnrollmentPresented: false, send: { _ in })
}

#Preview("非対応") {
    RootContent(availability: .unsupported, isProfileListPresented: false, isVoiceEnrollmentPresented: false, send: { _ in })
}

#Preview("一時的に利用不可") {
    RootContent(availability: .temporarilyUnavailable(.modelNotReady), isProfileListPresented: false, isVoiceEnrollmentPresented: false, send: { _ in })
}

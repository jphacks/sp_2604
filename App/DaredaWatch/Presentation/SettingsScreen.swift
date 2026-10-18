import SwiftUI

/// 本人の声の登録状況・Private Cloud Compute の利用・アプリのバージョン。
struct SettingsScreen: View {
    @Environment(PhoneSession.self) private var phoneSession
    let selfVoiceRecordTapped: () -> Void

    var body: some View {
        SettingsContent(
            settings: phoneSession.snapshot.settings,
            selfVoiceRecordTapped: selfVoiceRecordTapped,
            privateCloudComputeChanged: { phoneSession.send(.setPrivateCloudComputeEnabled($0)) }
        )
    }
}

struct SettingsContent: View {
    let settings: WatchSettings
    let selfVoiceRecordTapped: () -> Void
    let privateCloudComputeChanged: (Bool) -> Void

    var body: some View {
        List {
            SelfVoiceEnrollmentSection(enrollment: settings.selfVoiceEnrollment, recordTapped: selfVoiceRecordTapped) {
                if let registeredAt = settings.selfVoiceRegisteredAt {
                    LabeledContent("登録日", value: registeredAt, format: .dateTime.year().month().day())
                }
            }
            Section {
                Toggle(
                    "Private Cloud Compute",
                    isOn: Binding(get: { settings.isPrivateCloudComputeEnabled }, set: privateCloudComputeChanged)
                )
                .accessibilityIdentifier("watch.settings.pcc")
            } footer: {
                Text("要約などの処理を Apple のサーバーで行います")
            }
            if let appVersion = settings.appVersion {
                Section {
                    LabeledContent("バージョン", value: appVersion)
                }
            }
        }
        .navigationTitle("設定")
    }
}

/// 本人の声の登録。録音は Apple Watch で行い、登録は iPhone で行う。
struct SelfVoiceEnrollmentSection<Header: View>: View {
    let enrollment: WatchSelfVoiceEnrollmentState?
    let recordTapped: () -> Void
    @ViewBuilder var header: () -> Header

    var body: some View {
        Section {
            header()
            switch enrollment {
            case .processing:
                HStack {
                    ProgressView().frame(width: 24)
                    Text("iPhone で登録中")
                }
            case .completed:
                Label("登録しました", systemImage: "checkmark.circle")
            case let .failed(message):
                Label(message, systemImage: "exclamationmark.triangle")
            case nil:
                EmptyView()
            }
            Button(action: recordTapped) {
                Label("声を録音して登録", systemImage: "waveform")
            }
            .disabled(enrollment == .processing)
            .accessibilityIdentifier("watch.selfVoiceRecordButton")
        } header: {
            Text("本人の声")
        } footer: {
            Text("10 秒ほど話してください。会話の中から本人の発言を見分けるのに使います。")
        }
    }
}

extension SelfVoiceEnrollmentSection where Header == EmptyView {
    init(enrollment: WatchSelfVoiceEnrollmentState?, recordTapped: @escaping () -> Void) {
        self.init(enrollment: enrollment, recordTapped: recordTapped) { EmptyView() }
    }
}

#Preview {
    NavigationStack {
        SettingsContent(
            settings: WatchSettings(
                selfVoiceRegisteredAt: Date(timeIntervalSince1970: 1_800_000_000),
                isPrivateCloudComputeEnabled: true,
                appVersion: "1.0 (1)"
            ),
            selfVoiceRecordTapped: {},
            privateCloudComputeChanged: { _ in }
        )
    }
}

import Dependencies
import Foundation
import Observation

@Observable
final class SettingsViewModel {
    enum Action {
        case onAppear
        case reregisterVoiceButtonTapped
        case voiceReregistrationFinished
    }

    private(set) var selfVoiceRegisteredAt: Date?
    private(set) var isVoiceReregistrationPresented = false

    @ObservationIgnored
    @Dependency(\.fetchSelfVoiceUseCase) private var fetchSelfVoiceUseCase

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            Task { await fetch() }
        case .reregisterVoiceButtonTapped:
            isVoiceReregistrationPresented = true
        case .voiceReregistrationFinished:
            isVoiceReregistrationPresented = false
            Task { await fetch() }
        }
    }

    private func fetch() async {
        // 読み込みに失敗してもユーザーにできることがないため、登録日時を表示しないだけにする。
        selfVoiceRegisteredAt = try? await fetchSelfVoiceUseCase.execute()?.createdAt
    }
}

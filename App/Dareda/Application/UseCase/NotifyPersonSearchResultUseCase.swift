import Dependencies
import DependenciesMacros

/// 人物検索の結果を着信で知らせる。応答すると、1 位の候補の名前・所属・会った場所・前回の話の要約を読み上げる。
/// 候補がいない場合・追加の録音が必要な場合も、その旨を読み上げる。
///
/// 候補がいるのに着信で伝えられなかった (着信を出せない・拒否・応答なし) ときは、
/// 代わりに 1 位の名前だけをローカル通知する。アプリ表示中のローカル通知は表示されない
/// (UserNotificationClient が抑止する)。
///
/// 応答を待って読み上げ終えるまで戻らないため、呼び出し側は完了を待たずに呼ぶ。
@DependencyClient
nonisolated struct NotifyPersonSearchResultUseCase: Sendable {
    var execute: @Sendable (_ result: PersonSearchResult) async throws -> Void
}

nonisolated extension NotifyPersonSearchResultUseCase: DependencyKey {
    static let liveValue: NotifyPersonSearchResultUseCase = {
        let impl = NotifyPersonSearchResultUseCaseImpl()
        return NotifyPersonSearchResultUseCase(execute: impl.execute(_:))
    }()
}

nonisolated extension DependencyValues {
    var notifyPersonSearchResultUseCase: NotifyPersonSearchResultUseCase {
        get { self[NotifyPersonSearchResultUseCase.self] }
        set { self[NotifyPersonSearchResultUseCase.self] = newValue }
    }
}

private nonisolated struct NotifyPersonSearchResultUseCaseImpl: Sendable {
    @Dependency(\.profileRepository) private var profileRepository
    @Dependency(\.encounterRepository) private var encounterRepository
    @Dependency(\.voiceCallGateway) private var voiceCallGateway
    @Dependency(\.userNotificationGateway) private var userNotificationGateway

    func execute(_ result: PersonSearchResult) async throws {
        switch result {
        case .needsAdditionalRecording:
            _ = try await voiceCallGateway.announcePersonSearchNeedsAdditionalRecording()
        case let .candidates(matches):
            guard let top = matches.first else {
                _ = try await voiceCallGateway.announcePersonSearchNoProfiles()
                return
            }
            guard let profile = try await profileRepository.get(top.profileID) else { return }
            let encounter = try await encounterRepository.get(profile.id)
            let isAnswered: Bool
            do {
                isAnswered = try await voiceCallGateway.announcePersonSearchCandidate(
                    profile.name, profile.affiliation, encounter?.place?.name, encounter?.summary
                )
            } catch {
                // 着信を出せなくても、ローカル通知で結果を伝える
                isAnswered = false
            }
            guard !isAnswered else { return }
            try await userNotificationGateway.notifyPersonSearchCandidate(profile.name)
        }
    }
}

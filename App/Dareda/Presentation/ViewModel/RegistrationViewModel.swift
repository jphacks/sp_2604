import Dependencies
import Foundation
import Observation

@Observable
final class RegistrationViewModel {
    /// 登録に使う、本人を確定して要約まで済んだ解析結果。人物検索から遷移する場合も完了済みの結果をそのまま渡す。
    nonisolated struct Source: Sendable, Equatable {
        var recording: Recording
        var session: ProcessingSession
        /// 生成した要約。確認・編集の初期値で、保存ボタンが押されるまで保存しない。
        var summary: String
        var partnerVector: [Float]
    }

    enum Action {
        case nameChanged(String)
        case affiliationChanged(String)
        case metAtChanged(Date)
        case placeSelectButtonTapped
        case placeSearchPresentedChanged(Bool)
        case placeSelected(Place)
        case placeClearButtonTapped
        case summaryChanged(String)
        case saveButtonTapped
    }

    let source: Source
    private(set) var name = ""
    private(set) var affiliation = ""
    private(set) var metAt: Date
    private(set) var place: Place?
    private(set) var summary: String
    private(set) var isPlaceSearchPresented = false
    private(set) var isSaving = false
    private(set) var saveErrorMessage: LocalizedStringResource?
    private(set) var savedProfileID: Profile.ID?

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    @ObservationIgnored @Dependency(\.registerProfileUseCase) private var registerProfileUseCase

    init(source: Source) {
        self.source = source
        metAt = source.recording.startedAt
        summary = source.summary
    }

    func send(_ action: Action) {
        switch action {
        case let .nameChanged(name):
            self.name = name
        case let .affiliationChanged(affiliation):
            self.affiliation = affiliation
        case let .metAtChanged(metAt):
            self.metAt = metAt
        case .placeSelectButtonTapped:
            isPlaceSearchPresented = true
        case let .placeSearchPresentedChanged(isPresented):
            isPlaceSearchPresented = isPresented
        case let .placeSelected(place):
            self.place = place
            isPlaceSearchPresented = false
        case .placeClearButtonTapped:
            place = nil
        case let .summaryChanged(summary):
            self.summary = summary
        case .saveButtonTapped:
            save()
        }
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        saveErrorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                savedProfileID = try await registerProfileUseCase.execute(
                    name, affiliation, metAt, place, summary,
                    source.partnerVector, source.recording, source.session
                )
            } catch {
                // 入力は保持したまま、もう一度保存できるようにする
                saveErrorMessage = "保存できませんでした。もう一度お試しください。"
            }
        }
    }
}

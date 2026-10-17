import Dependencies
import Foundation
import Observation

@Observable
final class RegistrationViewModel {
    /// 登録に使う、本人を確定した解析結果。人物検索から遷移する場合も完了済みの結果をそのまま渡す。
    nonisolated struct Source: Sendable, Equatable {
        var recording: Recording
        var session: ProcessingSession
        var transcript: Transcript
        var partnerVector: [Float]
    }

    enum Action {
        case onAppear
        case nameChanged(String)
        case affiliationChanged(String)
        case metAtChanged(Date)
        case placeSelectButtonTapped
        case placeSearchPresentedChanged(Bool)
        case placeSelected(Place)
        case placeClearButtonTapped
        case summaryChanged(String)
        case summaryRetryButtonTapped
        case saveButtonTapped
    }

    let source: Source
    private(set) var name = ""
    private(set) var affiliation = ""
    private(set) var metAt: Date
    private(set) var place: Place?
    private(set) var summary = ""
    private(set) var isSummarizing = false
    private(set) var summaryErrorMessage: LocalizedStringResource?
    private(set) var isPlaceSearchPresented = false
    private(set) var isSaving = false
    private(set) var saveErrorMessage: LocalizedStringResource?
    private(set) var savedProfileID: Profile.ID?

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSummarizing && !isSaving
    }

    @ObservationIgnored @Dependency(\.conversationAnalysisService) private var conversationAnalysisService
    @ObservationIgnored @Dependency(\.registerProfileUseCase) private var registerProfileUseCase
    @ObservationIgnored private var hasAppeared = false

    init(source: Source) {
        self.source = source
        metAt = source.recording.startedAt
    }

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            guard !hasAppeared else { return }
            hasAppeared = true
            summarize()
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
        case .summaryRetryButtonTapped:
            summarize()
        case .saveButtonTapped:
            save()
        }
    }

    /// 要約は表示して確認・編集させるだけで、保存ボタンが押されるまで保存しない。
    private func summarize() {
        guard !isSummarizing else { return }
        isSummarizing = true
        summaryErrorMessage = nil
        Task {
            defer { isSummarizing = false }
            do {
                for try await event in conversationAnalysisService.summarize(source.transcript, source.session) {
                    if case let .completed(summary) = event { self.summary = summary.text }
                }
            } catch {
                summaryErrorMessage = "要約を作成できませんでした。再試行するか、要約を入力してください。"
            }
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

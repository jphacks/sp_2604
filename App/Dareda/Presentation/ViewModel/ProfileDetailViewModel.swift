import Dependencies
import Foundation
import Observation

@Observable
final class ProfileDetailViewModel {
    enum Action {
        case onAppear
        case editButtonTapped
        case editPresentedChanged(Bool)
        case nameChanged(String)
        case affiliationChanged(String)
        case metAtChanged(Date)
        case placeSelectButtonTapped
        case placeSearchPresentedChanged(Bool)
        case placeSelected(Place)
        case placeClearButtonTapped
        case summaryChanged(String)
        case editSaveButtonTapped
        case deleteButtonTapped
        case deleteConfirmationPresentedChanged(Bool)
        case deleteConfirmed
        case errorAlertDismissed
    }

    let profileID: Profile.ID
    private(set) var detail: ProfileDetailServiceModel?
    private(set) var isEditPresented = false
    private(set) var name = ""
    private(set) var affiliation = ""
    private(set) var metAt = Date()
    private(set) var place: Place?
    private(set) var summary = ""
    private(set) var isPlaceSearchPresented = false
    private(set) var isDeleteConfirmationPresented = false
    private(set) var isProcessing = false
    private(set) var errorMessage: LocalizedStringResource?
    /// 内容を更新した回数。変わったら一覧を読み直す。
    private(set) var updateCount = 0
    private(set) var isDeleted = false

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    @ObservationIgnored
    @Dependency(\.fetchProfileDetailUseCase) private var fetchProfileDetailUseCase
    @ObservationIgnored
    @Dependency(\.updateProfileUseCase) private var updateProfileUseCase
    @ObservationIgnored
    @Dependency(\.deleteProfileUseCase) private var deleteProfileUseCase

    init(profileID: Profile.ID) {
        self.profileID = profileID
    }

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            Task { await fetch() }
        case .editButtonTapped:
            guard let profile = detail?.profile else { return }
            name = profile.name
            affiliation = profile.affiliation
            // 前回の会話が未登録なら、現在の日時と空の要約から入力する
            metAt = detail?.encounter?.metAt ?? Date()
            place = detail?.encounter?.place
            summary = detail?.encounter?.summary ?? ""
            isEditPresented = true
        case let .editPresentedChanged(isPresented):
            isEditPresented = isPresented
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
        case .editSaveButtonTapped:
            save()
        case .deleteButtonTapped:
            isDeleteConfirmationPresented = true
        case let .deleteConfirmationPresentedChanged(isPresented):
            isDeleteConfirmationPresented = isPresented
        case .deleteConfirmed:
            delete()
        case .errorAlertDismissed:
            errorMessage = nil
        }
    }

    private func fetch() async {
        // 読み込みに失敗してもユーザーにできることがないため、何も表示しない。
        detail = try? await fetchProfileDetailUseCase.execute(profileID)
    }

    private func save() {
        guard canSave else { return }
        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                try await updateProfileUseCase.execute(profileID, name, affiliation, metAt, place, summary)
                isEditPresented = false
                await fetch()
                updateCount += 1
            } catch {
                // 入力は保持したまま、もう一度保存できるようにする
                errorMessage = "保存できませんでした。もう一度お試しください。"
            }
        }
    }

    private func delete() {
        guard !isProcessing else { return }
        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                try await deleteProfileUseCase.execute(profileID)
                isDeleted = true
            } catch {
                errorMessage = "削除できませんでした。もう一度お試しください。"
            }
        }
    }
}

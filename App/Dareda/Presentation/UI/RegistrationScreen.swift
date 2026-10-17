import SwiftUI

struct RegistrationScreen: View {
    @State private var viewModel: RegistrationViewModel
    let onSaved: (Profile.ID) -> Void

    init(source: RegistrationViewModel.Source, onSaved: @escaping (Profile.ID) -> Void) {
        _viewModel = State(initialValue: RegistrationViewModel(source: source))
        self.onSaved = onSaved
    }

    var body: some View {
        RegistrationContent(
            name: viewModel.name,
            affiliation: viewModel.affiliation,
            metAt: viewModel.metAt,
            place: viewModel.place,
            summary: viewModel.summary,
            isPlaceSearchPresented: viewModel.isPlaceSearchPresented,
            isSaving: viewModel.isSaving,
            canSave: viewModel.canSave,
            saveErrorMessage: viewModel.saveErrorMessage,
            send: viewModel.send
        )
        .onChange(of: viewModel.savedProfileID) { _, id in
            if let id { onSaved(id) }
        }
    }
}

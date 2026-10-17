import SwiftUI

struct VoiceEnrollmentScreen: View {
    let onCompleted: () -> Void
    /// `nil` ならキャンセルできない (初回登録)。
    var onCancelled: (() -> Void)?

    @State private var viewModel = VoiceEnrollmentViewModel()

    var body: some View {
        VoiceEnrollmentContent(
            isRecording: viewModel.isRecording,
            isProcessing: viewModel.isProcessing,
            failure: viewModel.failure,
            isCancellable: onCancelled != nil,
            isFileImporterPresented: viewModel.isFileImporterPresented,
            send: viewModel.send
        )
        .onChange(of: viewModel.isCompleted) { _, isCompleted in
            if isCompleted { onCompleted() }
        }
        .onChange(of: viewModel.isCancelled) { _, isCancelled in
            if isCancelled { onCancelled?() }
        }
    }
}

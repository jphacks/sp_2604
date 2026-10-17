import SwiftUI

struct VoiceEnrollmentScreen: View {
    let onCompleted: () -> Void

    @State private var viewModel = VoiceEnrollmentViewModel()

    var body: some View {
        VoiceEnrollmentContent(
            isRecording: viewModel.isRecording,
            isProcessing: viewModel.isProcessing,
            failure: viewModel.failure,
            send: viewModel.send
        )
        .onChange(of: viewModel.isCompleted) { _, isCompleted in
            if isCompleted { onCompleted() }
        }
    }
}

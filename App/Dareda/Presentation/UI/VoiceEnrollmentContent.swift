import SwiftUI

struct VoiceEnrollmentContent: View {
    let isRecording: Bool
    let isProcessing: Bool
    let failure: VoiceEnrollmentViewModel.Failure?
    var isCancellable = false
    let send: (VoiceEnrollmentViewModel.Action) -> Void

    private static let sampleText = """
        はじめまして。今日はお会いできてうれしいです。\
        私は普段、新しい技術やサービスについて調べたり、人と話したりするのが好きです。\
        最近は、週末に近所の公園を散歩しながら、季節の移り変わりを感じるようにしています。\
        春には桜、夏には青々とした木々、秋には紅葉、冬には澄んだ空気が楽しめます。\
        また、おいしいコーヒーを出すお店を探すのも趣味のひとつです。\
        もしおすすめの場所があれば、ぜひ教えてください。\
        これからどうぞよろしくお願いします。
        """

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    if isCancellable {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { send(.cancelButtonTapped) }
                                .disabled(isProcessing)
                                .accessibilityIdentifier("voiceEnrollment.cancelButton")
                        }
                    }
                }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("あなたの声を登録")
                        .font(.largeTitle.bold())
                        .accessibilityIdentifier("voiceEnrollment.title")
                    Text("会話の中であなたの声を見分けるために使います。静かな場所で、録音を開始してから下の文章を声に出して読んでください。")
                        .foregroundStyle(.secondary)
                }

                Text(Self.sampleText)
                    .font(.title3)
                    .lineSpacing(6)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 16))
                    .accessibilityIdentifier("voiceEnrollment.sampleText")

                if let failure {
                    Label(Self.message(for: failure), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("voiceEnrollment.failure")
                }

                actionButton
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isProcessing {
            ProgressView("登録中")
                .accessibilityIdentifier("voiceEnrollment.progress")
        } else if isRecording {
            Button("読み終わった", systemImage: "stop.fill") { send(.stopButtonTapped) }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .accessibilityIdentifier("voiceEnrollment.stopButton")
        } else {
            Button(failure == nil ? "録音を開始" : "もう一度録音", systemImage: "mic.fill") {
                send(.recordButtonTapped)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("voiceEnrollment.recordButton")
        }
    }

    private static func message(for failure: VoiceEnrollmentViewModel.Failure) -> String {
        switch failure {
        case .permissionDenied:
            "マイクの使用が許可されていません。設定アプリでマイクへのアクセスを許可してください。"
        case let .insufficientSpeech(duration):
            "声が十分に録音できませんでした (\(Int(duration))秒)。文章を最後まで読んで、\(Int(ProvisionalParameters.selfVoiceRequiredSpeechDuration))秒以上話してください。"
        case let .poorQuality(issues):
            issues.contains(.clipping)
                ? "音が割れています。マイクから少し離れて、もう一度録音してください。"
                : "声が小さすぎます。静かな場所で、もう少し大きな声で録音してください。"
        case .unexpected:
            "登録に失敗しました。もう一度録音してください。"
        }
    }
}

#Preview("録音前") {
    VoiceEnrollmentContent(isRecording: false, isProcessing: false, failure: nil, send: { _ in })
}

#Preview("録音中") {
    VoiceEnrollmentContent(isRecording: true, isProcessing: false, failure: nil, send: { _ in })
}

#Preview("再登録") {
    VoiceEnrollmentContent(isRecording: false, isProcessing: false, failure: nil, isCancellable: true, send: { _ in })
}

#Preview("発話不足") {
    VoiceEnrollmentContent(isRecording: false, isProcessing: false, failure: .insufficientSpeech(12), send: { _ in })
}

import AVFoundation
import Dependencies
import DependenciesMacros
import Synchronization

/// `AVSpeechSynthesizer` によるオンデバイスの読み上げ。アプリのオーディオセッションに出力する。
@DependencyClient
nonisolated struct SpeechSynthesizerClient: Sendable {
    /// 日本語で読み上げ、読み終わるまで待つ。キャンセルすると読み上げを止める。
    var speak: @Sendable (_ text: String) async -> Void
}

nonisolated extension SpeechSynthesizerClient: DependencyKey {
    static let liveValue: SpeechSynthesizerClient = {
        let impl = SpeechSynthesizerClientImpl()
        return SpeechSynthesizerClient(speak: impl.speak(_:))
    }()

    static let testValue = SpeechSynthesizerClient.inMemory()
    static let previewValue = SpeechSynthesizerClient.inMemory()
}

nonisolated extension DependencyValues {
    var speechSynthesizerClient: SpeechSynthesizerClient {
        get { self[SpeechSynthesizerClient.self] }
        set { self[SpeechSynthesizerClient.self] = newValue }
    }
}

/// `AVSpeechSynthesizer` は `Sendable` ではないが、読み上げの開始・停止はスレッドセーフに呼べる。
/// 読み終わりを待つ continuation は `Mutex` の中でだけ扱う。
private nonisolated final class SpeechSynthesizerClientImpl: NSObject, AVSpeechSynthesizerDelegate,
    @unchecked Sendable
{
    private let synthesizer = AVSpeechSynthesizer()
    private let pending = Mutex<CheckedContinuation<Void, Never>?>(nil)

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) async {
        await withTaskCancellationHandler {
            await withCheckedContinuation { (waiter: CheckedContinuation<Void, Never>) in
                start(text, resuming: waiter)
            }
        } onCancel: {
            stop()
        }
    }

    private func start(_ text: String, resuming waiter: CheckedContinuation<Void, Never>) {
        // 前の読み上げが終わっていなければ、待っている側を先に再開する
        let previous = pending.withLock { pending in
            let previous = pending
            pending = waiter
            return previous
        }
        previous?.resume()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        synthesizer.speak(utterance)
    }

    private func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func resume() {
        pending.withLock { pending in
            defer { pending = nil }
            return pending
        }?.resume()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        resume()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        resume()
    }
}

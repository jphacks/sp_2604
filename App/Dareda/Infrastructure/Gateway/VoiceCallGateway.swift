import Dependencies
import DependenciesMacros
import Foundation

/// 着信で結果を知らせる。応答したら内容を読み上げ、読み終わったら自動で通話を切る。
///
/// 各メソッドは通話が終わるまで待ち、ユーザーが応答したかを返す。着信を出せなければエラーを投げる。
@DependencyClient
nonisolated struct VoiceCallGateway: Sendable {
    /// 人物検索の 1 位の候補を読み上げる。所属・会った場所・前回の話の要約は、空なら読まない。
    var announcePersonSearchCandidate: @Sendable (
        _ name: String, _ affiliation: String, _ placeName: String?, _ summary: String?
    ) async throws -> Bool
    /// 人物検索の照合先 (保存済みのプロフィール) がいないことを読み上げる。
    var announcePersonSearchNoProfiles: @Sendable () async throws -> Bool
}

nonisolated extension VoiceCallGateway: DependencyKey {
    static let liveValue: VoiceCallGateway = {
        let impl = VoiceCallGatewayImpl()
        return VoiceCallGateway(
            announcePersonSearchCandidate: impl.announcePersonSearchCandidate(name:affiliation:placeName:summary:),
            announcePersonSearchNoProfiles: impl.announcePersonSearchNoProfiles
        )
    }()
}

nonisolated extension DependencyValues {
    var voiceCallGateway: VoiceCallGateway {
        get { self[VoiceCallGateway.self] }
        set { self[VoiceCallGateway.self] = newValue }
    }
}

private nonisolated struct VoiceCallGatewayImpl: Sendable {
    /// 相手に画面を見られても分からないよう、候補の名前ではなく汎用の名前を表示する。
    private static let callerName = "Dareda"
    /// 応答を待つ時間。着信中の実行時間の延長 (約 30 秒) に収まるようにする。
    private static let ringTimeout: Duration = .seconds(25)

    @Dependency(\.callKitClient) private var callKitClient
    @Dependency(\.speechSynthesizerClient) private var speechSynthesizerClient

    func announcePersonSearchCandidate(
        name: String, affiliation: String, placeName: String?, summary: String?
    ) async throws -> Bool {
        var sentences = ["この方は、\(name)さんではありませんか？"]
        if !affiliation.isEmpty {
            sentences.append("\(affiliation)所属です。")
        }
        if let summary, !summary.isEmpty {
            if let placeName, !placeName.isEmpty {
                sentences.append("前回は、\(placeName)で、次のような話をしました。")
            } else {
                sentences.append("前回は、次のような話をしました。")
            }
            sentences.append(summary)
        }
        return try await call(speaking: sentences.joined())
    }

    func announcePersonSearchNoProfiles() async throws -> Bool {
        try await call(speaking: "該当する人が見つかりませんでした。")
    }

    private func call(speaking message: String) async throws -> Bool {
        let id = UUID()
        let events = callKitClient.events(id)
        try await callKitClient.reportIncomingCall(id, Self.callerName)

        let timeout = Task { [callKitClient] in
            try await Task.sleep(for: Self.ringTimeout)
            await callKitClient.endCall(id, .unanswered)
        }
        var isAnswered = false
        var speech: Task<Void, Never>?
        for await event in events {
            switch event {
            case .answered:
                isAnswered = true
                timeout.cancel()
            case .audioActivated:
                guard speech == nil else { continue }
                speech = Task { [callKitClient, speechSynthesizerClient] in
                    await speechSynthesizerClient.speak(message)
                    guard !Task.isCancelled else { return }
                    await callKitClient.endCall(id, .remoteEnded)
                }
            case .ended:
                // 読み上げの途中で切られたら、読み上げも止める
                speech?.cancel()
            }
        }
        timeout.cancel()
        speech?.cancel()
        // 呼び出し元がキャンセルされてイベントの購読が終わった場合も、通話を残さない
        await callKitClient.endCall(id, .remoteEnded)
        return isAnswered
    }
}

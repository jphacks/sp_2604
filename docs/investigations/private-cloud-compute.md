# 会話要約の Private Cloud Compute 技術検証

確認日: 2026-10-17 / 対象: Issue [#13](https://github.com/jphacks/sp_2604/issues/13)

## 結論

iOS 27 の Foundation Models には PCC 用モデルを明示的に選択する API があり、会話要約の切替は技術的に可能。利用には Apple が承認する entitlement などの条件がある。API が存在することと、配布するアプリで利用できることは別に確認する。

この文書は調査結果を記録する。切替・分割要約の実装は [#30](https://github.com/jphacks/sp_2604/issues/30) の範囲とする。外部送信についてのユーザー説明・同意・無効化の仕様は未決であり、この調査で自動送信を承認した扱いにはしない。

## 証拠と検証範囲

- [既存の実機検証コメント](https://github.com/jphacks/sp_2604/issues/13#issuecomment-6228853249): Xcode 27.1 / iOS 27.1 SDK と macOS 27 実機での検証報告。本調査では過去の実機測定を再実行していない。
- リポジトリの `.xcode-version` は `27.1`。選択中の Xcode は `/Applications/Xcode-27.1.0.app`。
- iPhoneOS SDK の `FoundationModels.framework/Modules/FoundationModels.swiftmodule/arm64e-apple-ios.swiftinterface` を読み、下表の宣言を照合した。
- iOS 27.0 を target にした一時 Swift ファイルを `xcrun swiftc -typecheck` で検証し、PCC モデル生成、利用可否・上限・コンテキスト取得、トークン計算、モデル指定セッションと応答、3 種類の PCC エラー分岐がコンパイル可能であることを確認した。ネットワークリクエストは実行していない。

## API と切替方法

| 用途 | Xcode 27.1 SDK で確認した API |
| --- | --- |
| モデルの選択 | `LanguageModelSession(model: PrivateCloudComputeLanguageModel(), instructions: ...)`。暗黙の自動切替ではなくモデルを指定する |
| 利用可否 | `availability` / `isAvailable`。不可の理由は `deviceNotEligible` / `systemNotReady` |
| 利用量 | `quotaUsage.isLimitReached`、`status`。`belowLimit` の関連値に `isApproachingLimit` がある |
| 上限関連情報 | `quotaUsage.resetDate` / `limitIncreaseSuggestion` は optional。後者の `show()` でシステムの案内を表示できる |
| コンテキスト量 | オンデバイス: `SystemLanguageModel.default.contextSize`。PCC: `try await model.contextSize` |
| トークン計算 | `try await SystemLanguageModel.default.tokenCount(for: ...)`。prompt、instructions、transcript entries などの overload がある |
| PCC 固有エラー | `networkFailure` / `quotaLimitReached` / `serviceUnavailable`。`quotaLimitReached` の関連値に optional の `resetDate` がある |
| コンテキスト超過 | `LanguageModelError.contextSizeExceeded`。旧 `LanguageModelSession.GenerationError` の該当 API は iOS 27 で非推奨 |

既存コメントの `.quotaLimitReached(resetDate:)` や `.belowLimit(isApproachingLimit:)` は説明用の省略表記であり、Swift の実際の関連値は構造体。実装時は SDK の宣言に従う。

現在の `FoundationModelsClient.respond` は `LanguageModelSession(instructions:)` を使い、オンデバイス固定。`ConversationSummaryGateway` は話者ラベル付き文字起こしと指示文を渡している。PCC への切替・トークン予算判定・分割要約はまだ実装されていない。

## 利用条件と送信範囲

[Apple の利用条件](https://developer.apple.com/private-cloud-compute/)では、Small Business Program への加入、全アプリ合計の初回ダウンロード数 200 万未満、アカウントへの entitlement 付与が必要。Apple Intelligence 対応地域で App Store 配布、および TestFlight / ad hoc でのテストが可能。申請・承認状況は本調査では確認していない。

`App/Dareda/Dareda.entitlements` には `com.apple.developer.private-cloud-compute = true` が既に記載されている。このファイルの存在だけでは、承認・署名後の entitlement・プロビジョニングの有効性を保証しない。既存の実機報告では entitlement が無いリクエストが throw ではなくクラッシュしたため、利用不可ビルドでは PCC のコードパスへ入らない設計が必要。クラッシュ条件は本調査では再現していない。

PCC はオンライン処理で、ユーザーごとの日次上限がある。[Apple の WWDC26 説明](https://developer.apple.com/videos/play/wwdc2026/319/)を参照し、上限値やリセット時刻を固定しない。利用前の判定後にも状態は変化し得るため、リクエスト時の失敗処理も必要。

Dareda が現在の要約入力を PCC に渡す場合、要約対象の話者ラベル付き文字起こし全文と指示文が端末外で処理される。全文には会話で話された個人情報が含まれ得る。音声・声のベクトル・プロフィール DB・位置情報を追加送信する必要はない。これは今後の実装で守る送信範囲であり、現在のアプリが PCC へ送信しているという意味ではない。

[Apple の PCC セキュリティ要件](https://security.apple.com/documentation/private-cloud-compute/corerequirements)では、入力は当該リクエストの処理に限定して使い、永続保持しないとされる。これは端末内だけで処理することとは異なる。端末内の永続保存方針を維持しつつ、送信の説明と選択方法を #30 着手前に決める。

## #30 への実装案と残る検証

1. 指示文、話者ラベル、本文、セッション履歴やスキーマなどの入力に、出力と reasoning の余裕を加え、実行時の `contextSize` と比較する。文字数・録音分数を閾値にしない。System モデルのトークン数を PCC の厳密なトークン保証とせず、超過エラーにも対応する。
2. オンデバイスに収まればオンデバイスで生成する。超過し、ユーザーへの説明・選択、署名上の利用条件、availability、quota の条件が満たされる場合のみ PCC を候補にする。PCC のコンテキストにも収まらなければ分割する。
3. entitlement 未取得、利用不可、オフライン、上限到達、通信・サービス障害ではオンデバイス分割要約を代替案とする。拒否やキャンセルなどを一律に再送せず、エラー種別を分ける。オンデバイスも利用できない場合は失敗を上へ返し、再試行を画面側で扱う。
4. 分割は話者ラベルと発話境界を保ち、長い一発話も予算内に分ける。チャンク要約を再要約する際も予算を確認する。出力上限、最大段数・回数と縮小しない場合の停止条件を定め、無限再帰を防ぐ。原文にない情報を追加しない指示と要約品質を実機で評価する。
5. PCC が使えないときの分割要約、PCC 自体の超過、日次上限・通信障害、キャンセルを DataSource の差し替えで UI テストする。署名済み iPhone 実機で利用可否と成功時の動作、送信範囲を別途検証する。

過去の実機報告はオンデバイス 8,192 / PCC 32,768 tokens だったが、端末やモデルによらない保証値ではない。文字あたりのトークン数や会話時間への換算も入力次第で変わるため、切替条件に採用しない。

## 関連仕様

- [要求仕様書](https://app.notion.com/p/kantacky/3fb2468f4b0180f69822d8564f902b4d)
- [開発仕様書 (Phase 1)](https://app.notion.com/p/kantacky/3fb2468f4b01800b82c8e4dbcbc207ce)

2026-10-17 時点では両仕様書に API の実現可否が未検証として残っている。技術的には可能という本調査結果と、アカウント承認・同意設計・実装・品質検証が未完了であることを区別して参照する。

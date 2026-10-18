# Dareda

[![CI](https://github.com/jphacks/sp_2604/actions/workflows/ci.yml/badge.svg)](https://github.com/jphacks/sp_2604/actions/workflows/ci.yml)

![Dareda](https://jphacks.com/wp-content/uploads/2026/07/IMG_5316.png)

<!-- TODO: デモ動画のリンクを入れる (必須) -->
<!-- [デモ動画](https://youtu.be/xxxx) -->

## 製品概要

### 背景(製品開発のきっかけ、課題等）

「二度目まして」のとき、「この人、誰だ…」と焦った経験はないだろうか。
顔は覚えているのに、名前や前回話した内容が出てこない。聞き直すのも失礼な気がして、気まずいまま会話が終わってしまう。そんなとき、「隣でそっと教えてくれる人がいたらいいのに」と思ったのがきっかけである。

この悩みに対して、今ある手段はどれも決め手に欠ける。

| 手段 | 再会したその場で使えない理由 |
| --- | --- |
| 名刺・連絡先のメモ | 相手の名前が分からないと検索できない。相手の前で見返しにくい |
| 顔認識 | 相手にカメラを向ける必要がある。顔写真を集めること自体に抵抗がある |
| AI 議事録 (Notta・Plaud など) | 会話の記録や要約はできるが、目の前の相手が誰かは教えてくれない |

そこで、会話中は必ず相手の声が聞こえていることに着目した。声なら、カメラを向けなくても、名前を知らなくても、会話を始めるだけで手がかりが手に入る。

### 製品説明（具体的な製品の説明）

1対1の会話から相手の声の特徴と会話の要約を記録し、再会時に声で相手を特定して教えてくれる iOS アプリ。

1. **自分の声を登録** : 最初に例文を読み上げて、自分の声を登録する
2. **初対面で記録** : 会話を録音すると、自分と相手の声を聞き分け、相手の声の特徴(ベクトル)と会話の要約を、名前・所属・日時・場所と一緒にプロフィールとして保存する
3. **再会時に特定** : 会話を録音すると保存済みの声と照合し、最も声が近い人を、名前・所属・前回の話の要約と一緒に知らせる

#### 再会したときの流れ

1. 会話が始まったら、Apple Watch かコントロールセンターから録音を始める。アプリを開く必要はない
2. 少し話したら録音を止める。処理はバックグラウンドで続くので、iPhone はポケットに入れたままでよい
3. 結果が出ると、iPhone に電話がかかってくる。耳に当てると「この方は、〇〇さんではありませんか？△△所属です。前回は、□□で、次のような話をしました。」と読み上げてくれる
4. 電話に出られない場面では、Apple Watch の通知を手元でちらっと見て確認する

<!-- TODO: 各ステップのスクリーンショットか GIF を入れる -->

### 特長

#### 1. 相手の前でも不自然にならない知らせ方

相手の名前を確認するためにスマートフォンを操作すると、思い出せていないことが相手に伝わってしまう。Dareda は、その場の状況に合わせて目立たない方法で結果を知らせる。

| 方法 | デバイス | 使う場面 |
| --- | --- | --- |
| 着信と読み上げ | iPhone・AirPods | 電話に出るふりをして耳元で聞く。着信画面には相手の名前を出さない |
| 通知 | iPhone・Apple Watch | 手元をちらっと見て確認する |
| Live Activity | iPhone・Apple Watch | 録音から判定までの進み具合を、ロック画面や手元で確認する |

録音の開始も、Apple Watch のアプリ、コントロールセンター、ショートカットから、iPhone の画面を開かずにできる。Apple Watch のマイクで録音して iPhone に送ることもできる。

#### 2. 声を端末の外に出さない

- 文字起こし・話者分離・声のベクトル化・照合は、すべて端末内で処理する
- 会話の要約は Apple Intelligence のオンデバイスモデルで行い、端末で収まらない長さのときだけ、ユーザーの同意を得たうえで Private Cloud Compute (PCC) を使う
- 録音した音声・文字起こし・一時的なベクトルは、処理が終わったらすぐに削除する
- 残すのは、相手の声の特徴ベクトルと、ユーザーが確認・編集した要約だけ。データは端末内にだけ保存する

声や顔のような生体情報を扱うサービスは、サーバーに集めるほど不安が大きくなる。サーバーを持たずに完結させたことで、録音を使うアプリでも安心して使える。

### 解決出来ること

- 再会した相手の名前と前回の話題を、相手に気づかれずに思い出せる
- 名刺や連絡先を見返す手間がなくなり、会話そのものに集中できる
- 「前回〇〇の話をしましたよね」と会話を続けられ、人とのつながりを取りこぼさない

<!-- TODO: 実測値を入れる
#### 実際に試した結果

| 項目 | 結果 |
| --- | --- |
| 照合の正解率 | ◯人の声を登録した状態で、再会時の録音から正しい人を当てられた割合 ◯/◯ |
| 知らせるまでの時間 | 録音を止めてから着信が鳴るまで平均 ◯ 秒 (◯ 秒の録音) |
| 試してもらった人 | チーム外の ◯ 人に試してもらい、◯ 人が相手を思い出せた |
-->

想定する利用者は、展示会や学会、営業先、地域の集まりなど、一度会った人に時間をおいて再会することが多い人である。名刺交換が前提にならない場面でも、会話さえすれば記録が残る。

### 今後の展望

- **次に会う前の準備** : 前回の会話の要約から、次に話すとよい話題を Foundation Models で提案する
- **声以外の手がかり** : 話す速さや声の高さなど、話し方の特徴もプロフィールに残し、思い出すきっかけにする
- **複数人での会話** : 3人以上の会話から、それぞれの相手を特定する
- **精度と速さ** : 照合の精度を上げ、録音を止めてから知らせるまでの時間を短くする

### 注力したこと（こだわり等）

- **アプリを開かずに完結する使い方**
  録音の開始から結果の確認まで、iPhone の画面を見ずに済むようにした。Apple Watch、コントロールセンター、Live Activity、着信、通知を組み合わせ、相手の前でスマートフォンを操作しなくても使える。処理は `BGContinuedProcessingTask` でバックグラウンドでも続け、着信の読み上げは CallKit と端末内の音声合成で、サーバーなしで実現している。
- **自分の声と相手の声の聞き分け**
  録音には自分と相手の両方の声が入る。話者分離のあと、登録した自分の声と照合して自分を除き、残った話者を相手として扱う 2 段階の照合にした。文字起こしも単語単位で話者に割り当て、相手が話した内容を正しく要約できるようにした。
- **実機で録り直さずに精度を詰める仕組み**
  話者分離と本人識別をアプリと同じ処理で実行する評価用 CLI を作り、同じ録音でしきい値や話者数の設定を変えながら DER (話者分離の誤り率) と本人識別の正否を比べられるようにした。
- **プライバシー設計**
  声の処理はすべて端末内で行い、残すデータを声の特徴ベクトルと要約だけに絞った。

## 開発技術

### 動作環境

- 対象: Apple Intelligence 対応の iPhone (Apple Watch・AirPods は任意)
- 最低 OS: iOS 27.0

### 活用した技術

#### API・データ

- Foundation Models (Apple Intelligence のオンデバイス言語モデル / Private Cloud Compute) による会話の要約
- Speech (SpeechAnalyzer / SpeechTranscriber) によるオンデバイス文字起こし
- FluidAudio の話者分離 (OfflineDiarizer)
- ECAPA-TDNN (SpeechBrain) を Core ML に変換した話者埋め込みモデルによる声の照合
- MapKit (MKLocalSearch) による場所の検索

#### フレームワーク・ライブラリ・モジュール

- SwiftUI / Observation (`@Observable`)
- swift-dependencies (DI) / SQLiteData (ローカル DB)
- Core ML / AVFoundation / CallKit / UserNotifications
- ActivityKit / WidgetKit / App Intents (Live Activity・コントロール・ショートカット)
- WatchConnectivity (iPhone と Apple Watch の同期)
- BackgroundTasks (`BGContinuedProcessingTask`)
- XCUITest / スナップショットテスト (UI テスト・見た目の差分検出)
- Terraform / GitHub Actions / fastlane / Firebase App Distribution (インフラ・CI/CD・配信)

#### デバイス

- iPhone (Apple Intelligence 対応機種)
- Apple Watch (録音・通知・Live Activity)
- AirPods (着信の読み上げ)

### 独自技術

#### ハッカソンで開発した独自機能・技術

- 声の特徴ベクトルによる人物検索: [`SearchPersonUseCase.swift`](App/Dareda/Application/UseCase/SearchPersonUseCase.swift)
- 自分の声を除いて相手を特定する 2 段階の照合: [`VectorMatchingService.swift`](App/Dareda/Application/Service/VectorMatchingService.swift) / [`ConversationAnalysisService.swift`](App/Dareda/Application/Service/ConversationAnalysisService.swift)
- 話者分離・声の埋め込み: [`FluidAudioClient.swift`](App/Dareda/DataSource/FluidAudioClient/FluidAudioClient.swift)
- ECAPA-TDNN を、特徴量 (fbank) の計算まで含めて 1 つの Core ML モデルに変換するスクリプト: [`Tools/ecapa/convert.py`](Tools/ecapa/convert.py)
- 話者分離と本人識別の設定を比較する評価用 CLI: [`Tools/diarization-eval`](Tools/diarization-eval)
- 着信で相手の情報を読み上げる仕組み: [`VoiceCallGateway.swift`](App/Dareda/Infrastructure/Gateway/VoiceCallGateway.swift)
- 人物検索結果の通知 (iPhone・Apple Watch): [`NotifyPersonSearchResultUseCase.swift`](App/Dareda/Application/UseCase/NotifyPersonSearchResultUseCase.swift)
- Live Activity による録音・処理状況の表示: [`RecordingActivityGateway.swift`](App/Dareda/Infrastructure/Gateway/RecordingActivityGateway.swift)
- Apple Watch での録音と iPhone との同期: [`App/DaredaWatch`](App/DaredaWatch)

#### 開発の規模

Hack Day の 2 日間で、277 コミット・49 本の Pull Request を重ねて開発した。8 画面に 55 件の UI テストを用意し、CI で毎回実行している。

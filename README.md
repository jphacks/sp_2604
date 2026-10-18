# Dareda

[![CI](https://github.com/jphacks/sp_2604/actions/workflows/ci.yml/badge.svg)](https://github.com/jphacks/sp_2604/actions/workflows/ci.yml)

![IMAGE ALT TEXT HERE](https://jphacks.com/wp-content/uploads/2026/07/IMG_5316.png)

## 製品概要

### 背景(製品開発のきっかけ、課題等）

「二度目まして」のとき、「この人、誰だ…」と焦った経験はないだろうか。
顔は覚えているのに、名前や前回話した内容が出てこない。聞き直すのも失礼な気がして、気まずいまま会話が終わってしまう。そんなとき、「隣でそっと教えてくれる人がいたらいいのに」と思ったのがきっかけである。

そこで、会話中は必ず相手の声が聞こえていることに着目し、特定する鍵として「声」を使うことにした。

### 製品説明（具体的な製品の説明）

1対1の会話から相手の声の特徴と会話の要約を記録し、再会時に声で相手を特定して教えてくれる iOS アプリ。

1. **自分の声を登録** : 最初に自分の声を◯秒ほど登録
2. **初対面で記録** : 会話を録音すると、自分と相手の声を聞き分け、相手の声の特徴(ベクトル)と会話の要約を、名前・所属・日時・場所と一緒にプロフィールとして保存
3. **再会時に特定** : 会話を録音すると保存済みの声と照合し、確信度の高い順に候補を表示。1位の候補は通知で届く

### 特長

#### 1. iPhone・Apple Watch・AirPods の連携

スマートに使えるよう、デバイスをフル活用する。

| デバイス | 役割 |
| --- | --- |
| iPhone | 録音・話者識別・要約・照合・プロフィールの保存・通知 |
| Apple Watch | 手元への通知で、画面をちらっと見るだけで相手の情報を確認 |
| AirPods | 耳から通知で、相手の情報を確認 |

#### 2. プライバシーを守るオンデバイス処理

- 文字起こし・話者分離・声のベクトル化・照合は、基本的にすべて端末内で処理
- 録音した音声・文字起こし・一時ベクトルは処理後すぐに削除
- 残すのは、声の特徴ベクトルと、ユーザーが確認・編集した要約など必要なデータだけ
- 端末内で処理しきれないものだけを Private Cloud Compute (PCC) で処理

### 解決出来ること

- 再会した相手の名前や前回の話題などを、スマートに思い出せる
- 名刺や連絡先を見返す手間がなくなり、会話そのものに集中できる
- 「前回〇〇の話をしましたよね」と会話を続けられ、人とのつながりを取りこぼさない

### 今後の展望

- 識別精度向上と、照合にかかる時間の短縮
- 複数人での会話の対応

### 注力したこと（こだわり等）

- **スマートな使用方法**
  手元をちらっと見る、耳元で聞く、電話に出る。その場に合った方法で、相手が誰であるかをスマートに知ることができる。
  - Push 通知でさりげなく（iPhone・Apple Watch）
  - Live Activity でリアルタイムに（iPhone・Apple Watch）
  - 電話で自然に（iPhone・Apple Watch・AirPods）
- **安心して録音を使えるプライバシー設計**
  - 声の識別や照合は、基本的にすべて端末内で処理
  - 端末で処理しきれないものだけを、Apple の Private Cloud Compute で処理する
  - 録音した音声・文字起こしは処理が終わったらすぐに削除
  - 残すのは、声の特徴と、ユーザー自身が確認・編集した要約だけ
  - データはすべて端末内にだけ保存し、外部に保存しない

## 開発技術

### 動作環境

- 対象: Apple Intelligence 対応の iPhone のみ (iPad・Mac は対象外)
- 最低 OS: iOS 27.0 (暫定。実機検証後に確定する)

### 活用した技術

#### API・データ

- Foundation Models (Apple Intelligence のオンデバイス言語モデル / Private Cloud Compute) による会話の要約・分析
- Speech (SpeechAnalyzer / SpeechTranscriber) によるオンデバイス文字起こし
- MapKit (MKLocalSearch) による場所の検索
- FluidAudio の話者分離 (OfflineDiarizer) と、Core ML の話者埋め込みモデルによる声の照合

#### フレームワーク・ライブラリ・モジュール

- SwiftUI / Observation (`@Observable`)
- swift-dependencies (DI)
- SQLiteData (ローカル DB)
- FluidAudio (話者分離)
- Core ML / AVFoundation / UserNotifications
- XCUITest (UI テスト)
- Terraform / GitHub Actions / fastlane / Firebase App Distribution (インフラ・CI/CD・配信)

#### デバイス

- iPhone (Apple Intelligence 対応機種)
- Apple Watch (通知・Live Activity)
- AirPods (電話経由の通知)
- マイク (AVAudioRecorder による録音)
- ローカル通知 (人物検索結果の通知)

### 独自技術

#### ハッカソンで開発した独自機能・技術

- 声の特徴ベクトルによる人物検索: [`SearchPersonUseCase.swift`](App/Dareda/Application/UseCase/SearchPersonUseCase.swift)
- 話者分離・声の埋め込み: [`FluidAudioClient.swift`](App/Dareda/DataSource/FluidAudioClient/FluidAudioClient.swift)
- 人物検索結果の通知 (Push・Apple Watch): [`NotifyPersonSearchResultUseCase.swift`](App/Dareda/Application/UseCase/NotifyPersonSearchResultUseCase.swift)
- Live Activity による録音状況の表示: [`RecordingActivityGateway.swift`](App/Dareda/Infrastructure/Gateway/RecordingActivityGateway.swift)
- 電話での相手情報の通知: [`VoiceCallGateway.swift`](App/Dareda/Infrastructure/Gateway/VoiceCallGateway.swift)

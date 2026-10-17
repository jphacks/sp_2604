# サンプル（プロダクト名）

[![IMAGE ALT TEXT HERE](https://jphacks.com/wp-content/uploads/2026/07/IMG_5316.png)](https://www.youtube.com/watch?v=piaNsc6ilBI)

## 製品概要
### 背景(製品開発のきっかけ、課題等）
### 製品説明（具体的な製品の説明）
### 特長
#### 1. 特長1
#### 2. 特長2
#### 3. 特長3

### 解決出来ること
### 今後の展望
### 注力したこと（こだわり等）
* 
* 

## 開発技術
### 動作環境
* 対象: Apple Intelligence 対応の iPhone のみ (iPad・Mac は対象外)
* 最低 OS: iOS 27.0 (暫定。実機検証後に確定する)

### 活用した技術
#### API・データ
* Foundation Models (Apple Intelligence のオンデバイス言語モデル / Private Cloud Compute) による会話の要約・分析
* Speech (SpeechAnalyzer / SpeechTranscriber) によるオンデバイス文字起こし
* MapKit (MKLocalSearch) による場所の検索
* FluidAudio の話者分離 (OfflineDiarizer) と、Core ML の話者埋め込みモデルによる声の照合

#### フレームワーク・ライブラリ・モジュール
* SwiftUI / Observation (`@Observable`)
* swift-dependencies (DI)
* SQLiteData (ローカル DB)
* FluidAudio (話者分離)
* Core ML / AVFoundation / UserNotifications
* XCUITest (UI テスト)
* Terraform / GitHub Actions / fastlane / Firebase App Distribution (インフラ・CI/CD・配信)

#### デバイス
* iPhone (Apple Intelligence 対応機種)
* マイク (AVAudioRecorder による録音)
* ローカル通知 (人物検索結果の通知)

### 独自技術
#### ハッカソンで開発した独自機能・技術
* 独自で開発したものの内容をこちらに記載してください
* 特に力を入れた部分をファイルリンク、またはcommit_idを記載してください。

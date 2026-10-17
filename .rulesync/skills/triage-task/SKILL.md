---
name: triage-task
description: GitHub Project の Issue から取り組むタスクを決めて実装し、PR まで作成する。Issue 番号が指定されればその Issue を、なければ依存関係と優先度から次に取り組むべき Issue を選ぶ。着手前に不明点を質問し、回答を要求仕様書・開発仕様書・Issue 本文に反映する。実装中は commit スキル、完了時は pr スキルを使う。「タスクを進めて」「#12 をやって」「次のタスク」などと頼まれたときに使う。
---

# タスク実行

## 1. タスクの決定

### Issue 番号が指定された場合

`gh issue view <番号> --json number,title,body,state,labels,assignees` で取得し、そのまま手順 2 へ。Close 済みや依存未解決の場合はその旨を伝えて続行するか確認する。

### 指定がない場合

1. リポジトリ (`jphacks/sp_2604`) に紐づく GitHub Project を特定する。
   - `gh project list --owner jphacks` から該当 Project を探す。特定できなければユーザーに Project の URL を聞く。
2. Project のアイテムを取得する: `gh project item-list <Project番号> --owner jphacks --format json --limit 200`
   - Status / Priority / Iteration などのフィールド値を確認する。
3. 候補を絞り込む。
   - Open で、Status が未着手 (Todo / Backlog 相当) のもの。
   - 他人にアサインされているものは除外する。
   - **依存関係が解決済み** のもの。依存は以下の両方を確認し、依存先が全て Close 済みであること:
     - Issue 本文の「依存するIssue」セクション
     - GitHub の Issue dependencies: `gh api repos/jphacks/sp_2604/issues/<番号>/dependencies/blocked_by`
   - 依存先が Open でも、依存先を実装したブランチの PR が既に存在する (In Review 相当) 場合は候補に含めてよい。その場合は手順 2 で Stacked PR として積む。
4. 優先順位を付ける: Priority フィールド (高い順) → 他の Issue をブロックしている数 (多い順) → Iteration / 期日 → Issue 番号 (小さい順)。
5. 選んだ Issue と選定理由 (依存・優先度) を 1〜2 行でユーザーに示し、他の候補も上位 2〜3 件挙げて、着手してよいか確認する。

## 2. 着手準備

1. ベースブランチを決める。
   - 依存先の Issue が無い、または全て Close 済みなら `main`。
   - Open の依存先がある場合は、その依存先を実装したブランチ (依存先 Issue に紐づく PR の head branch。`gh pr list --search "<依存先番号> in:body" --json number,headRefName,state` や `gh issue view <依存先番号> --json closedByPullRequestsReferences` で特定) をベースにする。Open の依存先が複数あり、それらが同じスタック上に無い場合は、ユーザーにどれをベースにするか確認する。
2. ベースブランチを最新化し、そこから `feature/<番号>-<短い英語の説明>` ブランチを作る。
   - ベースが `main`: `git switch main && git pull` → `git switch -c feature/<番号>-<説明>`
   - ベースが依存先ブランチ: `gh extension install github/gh-stack` (未導入時) の後、`git switch <依存先ブランチ> && git pull`。依存先ブランチがまだスタック管理されていなければ `gh stack init <依存先ブランチ>` (依存先がさらに別ブランチに積まれているなら下から順に列挙) で取り込み、`gh stack add feature/<番号>-<説明>` で上に積む。
   - 決めたベースブランチは手順 5 の PR 作成時に `pr` スキルへ渡す。
3. Issue を自分にアサインし、Project の Status を In Progress 相当に更新する (`gh issue edit <番号> --add-assignee @me`、`gh project item-edit`)。

## 3. 不明点の解消

着手前に以下を読み、仕様の曖昧さ・抜けを洗い出す。

- Issue 本文 (概要 / 対応内容 / 注意点 / 受け入れ基準 / 依存するIssue / 関連リンク)
- 要求仕様書・開発仕様書 (Notion)。リンクは Issue 本文の「関連リンク」にあるので、Notion MCP (`notion-fetch`) で読む。
- 関連する既存コードと `architecture` ルール

不明点があれば AskUserQuestion でまとめて質問する (推奨案を先頭に)。既存コードや慣習から判断できることは質問せず、判断内容を後で報告する。

回答を得たら、実装前に以下へ反映する。

- **要求仕様書** (Notion): ユーザーから見た振る舞い・機能要件・制約。Notion MCP (`notion-update-page`) で該当箇所を更新する。
- **開発仕様書** (Notion): 画面構成、レイヤごとの型、データ構造、外部 API など実装上の決定事項。同様に更新する。
- **Issue 本文**: `gh issue edit <番号> --body-file <file>` で、テンプレートの各セクション (対応内容 / 注意点 / 受け入れ基準) を更新する。決定事項は該当箇所に追記する。

Issue に仕様書のリンクが無い場合は、ユーザーにリンクを聞き、Issue の「関連リンク」に追加する。

## 4. 実装

- `architecture` ルールに従う。
- UI を追加・変更した場合は `App/DaredaUITests/<Screen Name>ScreenTests.swift` に UI テストを追加し、実行して通ることを確認する。
- ビルドが通ることを確認する。
- 意味のある区切りごとに **`commit` スキル** でコミットする (最後にまとめてコミットしない)。
- 実装中に新たな不明点が出たら、作業を止めて質問し、手順 3 と同様に仕様書・Issue に反映する。

## 5. 完了

1. Issue の受け入れ基準を全て満たしているか確認し、満たしたものは Issue 本文のチェックボックスを更新する。
2. **`pr` スキル** で PR を作成する。Base branch には手順 2 で決めたベースブランチを指定する (依存先ブランチがベースの場合は Stacked PR になる)。
3. Project の Status を In Review 相当に更新し、PR の URL を報告する。

---
name: pr
description: Base branch との差分全体を確認し、PR テンプレートに沿って日本語のタイトル・本文で GitHub Pull Request を作成する。UI 変更時は iPhone 18 Pro シミュレーターで Before/After のスクリーンショットを撮って添付し、kantacky・mikaminasaki・tanakarinna にレビューを依頼する。「PR を作って」と頼まれたとき、またはタスク完了時に使う。
---

# PR 作成

## 1. 事前確認

1. 未コミットの差分があれば、先に `commit` スキルでコミットする。
2. Base branch を決める (指定がなければ `main`)。`git fetch origin <base>` で最新化する。
   - 指定がなくても、関連 Issue に Open の依存先 Issue があり、現在ブランチがその依存先の実装ブランチから切られている場合は、依存先ブランチを base とする (Stacked PR)。依存先が Close 済みなら `main` でよい (依存先ブランチがマージ済みなら `gh stack rebase` / `git rebase origin/main` で main に載せ替える)。
3. 現在ブランチが base と同じなら、作業内容を表すブランチ (例: `feature/123-profile-screen`) を切ってから進める。

## 2. 差分の把握

コミットメッセージだけに頼らず、差分全体を根拠にする。

- `git log --oneline origin/<base>..HEAD`
- `git diff --stat origin/<base>...HEAD`
- `git diff origin/<base>...HEAD`
- ブランチ名・コミット・会話から関連 Issue を特定し、`gh issue view <番号>` で受け入れ基準を確認する。受け入れ基準を全て満たすなら Close 対象とする。

## 3. UI 差分のスクリーンショット (UI を変更した場合のみ)

`App/Dareda/Presentation/` 配下 (UI / Component / ViewModel の表示に影響する変更) やアセットに変更がある場合に行う。

1. シミュレーター操作用の MCP (XcodeBuildMCP など) を使い、**iPhone 18 Pro** シミュレーターを起動する。
2. **Before**: `git worktree add $TMPDIR/dareda-base origin/<base>` で base の作業ツリーを作り、そこで `Dareda.xcworkspace` / スキーム `Dareda` をビルド・起動し、該当画面まで遷移してスクリーンショットを撮る。終わったら `git worktree remove` で片付ける。
3. **After**: 現在ブランチで同様にビルド・起動し、同じ画面・同じ状態で撮る。
   - 画面へのデータ投入が必要なら `UI_TEST_SCENARIO` の launch environment を使い、Before/After で状態を揃える。
   - 新規画面で Before が存在しない場合は Before を「なし」とする。
4. 画像をアップロードする。リポジトリはパブリックなので、画像用の orphan ブランチ `pr-assets` に置いて raw URL で参照する:
   ```sh
   # pr-assets ブランチの worktree に pr/<ブランチ名>/<画面名>-before.png 等を追加して commit・push
   # 参照 URL: https://raw.githubusercontent.com/jphacks/sp_2604/pr-assets/pr/<ブランチ名>/<画面名>-after.png
   ```
   `pr-assets` が無ければ `git switch --orphan pr-assets` 相当を worktree 上で作る。作業ブランチに画像をコミットしない。

## 4. PR の作成

- **タイトル**: 変更内容が簡潔に分かる日本語 (prefix なし)。
- **本文**: `.github/pull_request_template.md` の全セクションを日本語で埋める。該当なしのセクションは「なし」と書き、削除しない。
  - 変更内容: 箇条書き。
  - 関連Issue: `#123` 形式。マージで Close できるものは `Close #123`。
  - 関連リンク: 関連 Issue に記載の Notion 仕様書、デザイン、参考資料。
  - 追加したUIテスト: `App/DaredaUITests/` に追加したテストを「画面名 | テストケース名」の表で。
  - UI差分: 手順 3 の画像を「画面名 | Before | After」の表で (`<img src="..." width="300">`)。
  - 末尾にシステムから指示された attribution があれば付ける。
- 作成:

```sh
git push -u origin HEAD
gh pr create --base <base> --title "<タイトル>" --body-file <本文ファイル> \
  --assignee @me \
  --reviewer kantacky,mikaminasaki,tanakarinna
```

- **Stacked PR の場合** (base が `main` 以外の依存先ブランチ) は、[GitHub の Stacked PR](https://docs.github.com/en/pull-requests/get-started/about-stacked-prs) として作る。`gh pr create` ではなく `gh-stack` 拡張を使う:

```sh
gh extension install github/gh-stack   # 未導入時のみ
# 現在ブランチがスタック未登録なら、下のブランチから順に登録する
gh stack init <依存先ブランチ> <現在ブランチ>
gh stack submit --auto --open          # 各ブランチを push し、下のブランチを base にした PR を作成・リンク
# submit はタイトル・本文・レビュアーを指定できないため、作成された PR を上書きする
gh pr edit <現在ブランチ> --title "<タイトル>" --body-file <本文ファイル> \
  --add-assignee @me \
  --add-reviewer kantacky,mikaminasaki,tanakarinna
```

  - `gh pr view --json baseRefName` で base が依存先ブランチになっていることを確認する。
  - 本文の「関連Issue」に依存先 PR を `依存: #<PR番号>` として記載する。
  - 下の PR がマージされると上の PR は自動で rebase・retarget されるので手動での base 変更は不要。
- PR 作成者自身はレビュアーに指定できないため、自分が 3 名のいずれかなら残りの 2 名にする。
- 作成後、PR の URL を報告する。

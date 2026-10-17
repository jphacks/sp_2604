#!/bin/bash
# xcresult から XCTAttachment のスクリーンショットを取り出し、reg-suit の比較対象として並べる。
# ファイル名は <テストクラス>/<テストメソッド>_<attachment 名>.png にして、実行ごとに変わらないようにする。
set -euo pipefail

xcresult="$1"
output_dir="$2"
export_dir="$(mktemp -d)"
trap 'rm -rf "$export_dir"' EXIT

rm -rf "$output_dir"
mkdir -p "$output_dir"

xcrun xcresulttool export attachments --path "$xcresult" --output-path "$export_dir"

jq -r '
  .[] | .testIdentifier as $test | .attachments[]
  | select(.exportedFileName | endswith(".png"))
  | [.exportedFileName, $test, (.suggestedHumanReadableName | sub("_[0-9]+_[0-9A-Fa-f-]{36}\\.png$"; ""))]
  | @tsv
' "$export_dir/manifest.json" | while IFS=$'\t' read -r file test name; do
  test="${test%()}"
  mkdir -p "$output_dir/$(dirname "$test")"
  cp "$export_dir/$file" "$output_dir/${test}_${name}.png"
done

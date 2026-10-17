---
root: false
targets: ["*"]
description: "Terraform のディレクトリ構成とコーディングルール"
globs: ["terraform/**/*"]
---

# Terraform ガイド

`terraform/` 配下のコードを追加・変更するときに従うルール。

## ディレクトリ構成

```
terraform/
├── <root module name>/        // 1 ディレクトリ = 1 root module = 1 state
│   ├── main.tf                // terraform / provider ブロックとリソース
│   ├── variables.tf
│   ├── outputs.tf             // 出力がある場合のみ
│   └── .terraform.lock.hcl    // コミットする
└── modules/
    └── <module name>/         // 複数の root module で再利用するモジュール
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

- root module は管理対象のサービス単位で分ける (例: `github/`, `firebase/`)。`terraform/` 直下に `.tf` を置かない。
- state は GCS バケット `dareda-jphacks2026-tfstate` に保存する。backend の `prefix` は root module 名と同じにする。バケットは `mise run tfstate:bootstrap` で作成済みの前提とし、Terraform では管理しない。
- 実行は各 root module のディレクトリで行う (`cd terraform/github && terraform plan`)。root module 同士は state を共有せず、参照し合わない。
- `modules/` は、複数の root module から使う場合にだけ作る。1 か所でしか使わないものは root module 内に直接書く。
- 空のディレクトリは作らない。必要になった時点で作る。
- リソースが増えて `main.tf` が長くなったら、同じディレクトリ内でリソース種別ごとに `<種別>.tf` (例: `secrets.tf`) へ分割する。

## ルール

- シークレットの値を Terraform に渡さない。値は各サービスの設定画面から直接入力し、Terraform は箱 (名前) だけを管理する。値の変更は `lifecycle { ignore_changes }` で無視する。
- `*.tfstate`・`.terraform/`・`*.tfvars` はコミットしない (state はローカルに置かず GCS を使う)。`.terraform.lock.hcl` はコミットする。
- provider は `required_providers` でバージョン制約 (`~>`) を付ける。
- 複数の同種リソースは `for_each` で定義し、`count` は使わない。
- 変数には必ず `description` と `type` を書く。
- コミット前に `terraform fmt` を通す。

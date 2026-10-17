terraform {
  required_version = ">= 1.9"

  backend "gcs" {
    bucket = "dareda-jphacks2026-tfstate"
    prefix = "github"
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = var.github_owner
}

# 値は GitHub の設定画面から直接入力する。Terraform は名前だけを管理し、
# 作成時のプレースホルダー以降の値の変更は無視する。
locals {
  actions_secrets = toset([
    "MATCH_PASSWORD",
    "CERTIFICATES_APP_PRIVATE_KEY",
    "FIREBASE_APP_ID",
  ])

  actions_variables = toset([
    "CERTIFICATES_APP_CLIENT_ID",
    "FIREBASE_WORKLOAD_IDENTITY_PROVIDER",
    "FIREBASE_SERVICE_ACCOUNT",
  ])
}

resource "github_actions_secret" "this" {
  for_each = local.actions_secrets

  repository      = var.github_repository
  secret_name     = each.key
  plaintext_value = "CHANGE_ME"

  lifecycle {
    ignore_changes = [plaintext_value, encrypted_value]
  }
}

resource "github_actions_variable" "this" {
  for_each = local.actions_variables

  repository    = var.github_repository
  variable_name = each.key
  value         = "CHANGE_ME"

  lifecycle {
    ignore_changes = [value]
  }
}

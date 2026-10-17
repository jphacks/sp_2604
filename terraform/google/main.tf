terraform {
  required_version = ">= 1.9"

  backend "gcs" {
    bucket = "dareda-jphacks2026-tfstate"
    prefix = "google"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

resource "google_project_service" "this" {
  for_each = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "firebaseappdistribution.googleapis.com",
  ])

  service            = each.key
  disable_on_destroy = false
}

# GitHub Actions の OIDC トークンで認証するための Workload Identity Federation
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.this]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }
  # 指定したリポジトリ以外からのトークンを拒否する
  attribute_condition = "assertion.repository == \"${var.github_repository}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "firebase_distribution" {
  account_id   = "firebase-distribution"
  display_name = "Firebase App Distribution (GitHub Actions)"

  depends_on = [google_project_service.this]
}

resource "google_project_iam_member" "firebase_distribution" {
  project = var.project_id
  role    = "roles/firebaseappdistro.admin"
  member  = google_service_account.firebase_distribution.member
}

resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.firebase_distribution.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

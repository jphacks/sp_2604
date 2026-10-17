# reg-suit (VRT) の期待値画像とレポートを置くバケット
resource "google_storage_bucket" "vrt" {
  name                        = "${var.project_id}-vrt"
  location                    = "ASIA-NORTHEAST1"
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.this]
}

# PR コメントのレポート URL をブラウザで開けるよう、閲覧を公開する
resource "google_storage_bucket_iam_member" "vrt_public_read" {
  bucket = google_storage_bucket.vrt.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_service_account" "vrt" {
  account_id   = "vrt-reg-suit"
  display_name = "reg-suit VRT (GitHub Actions)"

  depends_on = [google_project_service.this]
}

resource "google_storage_bucket_iam_member" "vrt" {
  bucket = google_storage_bucket.vrt.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.vrt.member
}

resource "google_service_account_iam_member" "vrt_workload_identity_user" {
  service_account_id = google_service_account.vrt.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

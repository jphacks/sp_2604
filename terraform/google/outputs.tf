output "workload_identity_provider" {
  description = "GitHub の変数 FIREBASE_WORKLOAD_IDENTITY_PROVIDER に設定する値"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "firebase_service_account" {
  description = "GitHub の変数 FIREBASE_SERVICE_ACCOUNT に設定する値"
  value       = google_service_account.firebase_distribution.email
}

output "vrt_service_account" {
  description = "GitHub の変数 VRT_SERVICE_ACCOUNT に設定する値"
  value       = google_service_account.vrt.email
}

output "vrt_bucket_name" {
  description = "GitHub の変数 VRT_BUCKET_NAME に設定する値"
  value       = google_storage_bucket.vrt.name
}

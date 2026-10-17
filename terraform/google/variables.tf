variable "project_id" {
  description = "Firebase プロジェクトの Google Cloud プロジェクト ID"
  type        = string
  default     = "dareda-jphacks2026"
}

variable "github_repository" {
  description = "Workload Identity Federation を許可する GitHub リポジトリ (<owner>/<repo>)"
  type        = string
  default     = "jphacks/sp_2604"
}

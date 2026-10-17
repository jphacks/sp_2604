variable "github_owner" {
  description = "GitHub の Organization またはユーザー名"
  type        = string
  default     = "jphacks"
}

variable "github_repository" {
  description = "Actions シークレットを設定するリポジトリ名"
  type        = string
  default     = "sp_2604"
}

variable "region" {
  description = "リソースを作成するリージョン。Control Tower の統治リージョンと揃える"
  type        = string
  default     = "ap-northeast-1"
}

variable "bucket_name" {
  description = <<-EOT
    バックアップ用 S3 バケット名。S3 のバケット名はグローバルに一意である必要があるため
    アカウント ID を含める。
  EOT
  type        = string
  default     = "bento-manager-backup-394123064455"
}

variable "replica_prefix" {
  description = <<-EOT
    Litestream が書き込むプレフィックス。IAM ポリシーはこの配下だけを許可する。
    Litestream 側の replica url もこれに合わせること（ADR-0001 決定 9）。
  EOT
  type        = string
  default     = "production"
}

variable "noncurrent_version_retention_days" {
  description = "非現行バージョンの保持日数。ADR-0001 決定 7 の 30 日と揃える"
  type        = number
  default     = 30
}

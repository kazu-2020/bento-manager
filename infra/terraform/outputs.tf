output "bucket_name" {
  description = "バックアップ用 S3 バケット名"
  value       = aws_s3_bucket.backup.id
}

output "litestream_replica_url" {
  description = "litestream.yml の replica url に設定する値"
  value       = "s3://${aws_s3_bucket.backup.id}/${var.replica_prefix}"
}

output "litestream_user_arn" {
  description = <<-EOT
    Litestream 用 IAM ユーザーの ARN。
    アクセスキーは state に載せないため Terraform では発行していない。
    以下のコマンドで手動発行し、1Password に保存すること。

      aws iam create-access-key --user-name litestream
  EOT
  value       = aws_iam_user.litestream.arn
}

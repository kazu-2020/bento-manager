output "litestream_replica_url" {
  description = "litestream.yml の replica url に設定する値"
  value       = "s3://${aws_s3_bucket.backup.id}/${local.replica_prefix}"
}

output "litestream_user_arn" {
  description = "Litestream 用 IAM ユーザーの ARN。アクセスキーは Terraform では発行しない"
  value       = aws_iam_user.litestream.arn
}

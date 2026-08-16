output "litestream_replica_url" {
  description = "litestream.yml の replica url に設定する値"
  value       = "s3://${aws_s3_bucket.backup.id}/${local.replica_prefix}"
}

output "litestream_user_arn" {
  description = "Litestream 用 IAM ユーザーの ARN。アクセスキーは Terraform では発行しない"
  value       = aws_iam_user.litestream.arn
}

output "restore_drill_monitor_id" {
  description = <<-EOT
    リストア訓練の Sentry Cron Monitor の内部 ID。
    チェックインに使う slug はプロバイダーが返さないため、apply 後に
    Sentry のダッシュボード（Crons）で確認して #247 に記載すること。
  EOT
  value       = sentry_cron_monitor.restore_drill.id
}

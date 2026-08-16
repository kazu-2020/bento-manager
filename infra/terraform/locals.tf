# variable ではなく locals にしている。cloud ブロックが組織・プロジェクト・
# ワークスペースを名指しで固定しており呼び出し元は 1 つしか存在しないため、
# variable にすると HCP Terraform の画面から git に痕跡を残さず上書きできてしまう。
# ADR-0002 決定 3 が VCS ワークフローで塞いだ経路を開け直すことになる。
locals {
  # Control Tower の統治リージョンと揃える
  region = "ap-northeast-1"

  # S3 のバケット名はグローバルに一意である必要があるためアカウント ID を含める。
  # data.aws_caller_identity で導出しないのは、誤ったアカウントに対して apply した際に
  # バケット名も追随してしまい、黙って別のバケットが作られるため。
  bucket_name = "bento-manager-backup-394123064455"

  # Litestream が書き込むプレフィックス。IAM ポリシーはこの配下だけを許可する。
  # 本番の litestream.yml の replica url もこれに合わせること。
  replica_prefix = "production"

  # ADR-0001 決定 7 と揃える
  noncurrent_version_retention_days = 30
}

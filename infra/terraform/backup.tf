resource "aws_s3_bucket" "backup" {
  bucket = local.bucket_name
}

# ADR-0001 決定 9: 本番サーバー内に置く認証情報からバックアップを消されても、
# 非現行バージョンとして残るようにする。
resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ADR-0001 の「決定不要として閉じた論点」より。S3 は 2023 年以降すべての新規オブジェクトに
# SSE-S3 を既定適用するが、既定に依存せず明示する。
resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ADR-0001 決定 7 と揃えて非現行バージョンを失効させる。
# 現行バージョンには失効を設定しない。Litestream は compaction と保持期間管理のために
# 日常的にオブジェクトを削除しており、現行バージョンの寿命は Litestream 側が管理する。
resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = local.noncurrent_version_retention_days
    }

    # Litestream の DeleteObject はバージョニング下で delete marker を作る。
    # 非現行バージョンが失効した後も delete marker だけが孤児として残るため、
    # これを消さないとこの構成で唯一、上限なく増え続ける項目になる。
    expiration {
      expired_object_delete_marker = true
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # バージョニングが有効になる前にライフサイクルを設定すると
  # noncurrent_version_expiration が意味を持たない
  depends_on = [aws_s3_bucket_versioning.backup]
}

# path はこのアカウント内での分類のためのもので、権限には影響しない。
#
# アクセスキーはここでは作らない。Terraform で作ると state に平文で載るため、
# 手動で発行して 1Password に保存し、kamal secrets 経由で本番に渡す。
# run ロールにも作成権限を与えていない（infra/bootstrap/tfc-run-role-policy.yaml）。
resource "aws_iam_user" "litestream" {
  name = "litestream"
  path = "/bento-manager/"
}

resource "aws_iam_user_policy" "litestream" {
  name = "litestream-s3-access"
  user = aws_iam_user.litestream.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ListBucket はバケット単位の権限なので、Condition でプレフィックスを絞る。
        # Litestream が prefix なしで列挙する挙動を示した場合はここが AccessDenied になる。
        # その際は Condition を外し、Resource のプレフィックス限定だけを残す。
        Sid      = "ListBucketWithinPrefix"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.backup.arn
        Condition = {
          StringLike = {
            "s3:prefix" = ["${local.replica_prefix}/*"]
          }
        }
      },
      {
        # DeleteObject は必須。Litestream は compaction と保持期間管理で日常的に削除する
        # （ADR-0001 決定 9 で Object Lock を採らなかった理由）。
        Sid    = "ObjectAccessWithinPrefix"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = "${aws_s3_bucket.backup.arn}/${local.replica_prefix}/*"
      },
    ]
  })
}

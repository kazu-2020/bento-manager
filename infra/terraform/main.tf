terraform {
  required_version = "~> 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.60"
    }

    # 0.x のため破壊的変更が入りうる。パッチ版のみ許可する
    sentry = {
      source  = "jianyuan/sentry"
      version = "~> 0.15.4"
    }
  }

  cloud {
    organization = "matazou_organization"

    workspaces {
      project = "workload"
      name    = "bento-manager"
    }
  }
}

# 認証情報は OIDC により run のたびに動的に発行される。アクセスキーは保存しない。
# 経緯と責任分界は docs/adr/0002-backup-infrastructure.md の決定 4・5 を参照。
provider "aws" {
  region = local.region

  default_tags {
    tags = {
      ManagedBy = "terraform"
    }
  }
}

# 認証はワークスペースの環境変数 SENTRY_AUTH_TOKEN から読む。
# AWS と違い Sentry は OIDC に対応しないため、静的トークンを受け入れている。
# トークンは internal integration でスコープを絞って発行すること。
provider "sentry" {}

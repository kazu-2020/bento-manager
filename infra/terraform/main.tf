terraform {
  required_version = "~> 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.60"
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

# 認証情報はワークスペースの環境変数（TFC_AWS_PROVIDER_AUTH / TFC_AWS_RUN_ROLE_ARN）
# 経由で OIDC により動的に発行される。アクセスキーはどこにも保存しない。
#
# ロールと OIDC プロバイダーは HCP Terraform の Dynamic provider credentials が作成する。
# run ロールに与える権限は infra/bootstrap/tfc-run-role-policy.yaml で定義している。
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "bento-manager"
      ManagedBy = "terraform"
    }
  }
}

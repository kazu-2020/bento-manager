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

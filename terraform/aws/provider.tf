terraform {
  required_version = "~> 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket       = "terraform-state-manage-kohta"
    region       = "ap-northeast-1"
    key          = "aws/tfstate"
    use_lockfile = true
  }
}

# 認証情報はデフォルトのAWS認証情報チェーンに委ねる(backendのS3と同様)
provider "aws" {
  region = "ap-northeast-1"
}

terraform {
  required_version = "~> 1.11.0"
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.3.0"
    }
  }
  backend "s3" {
    bucket       = "terraform-state-manage-kohta"
    region       = "ap-northeast-1"
    key          = "snowflake/tfstate"
    use_lockfile = true
  }
}

provider "snowflake" {
  organization_name = var.SNOWFLAKE_ORGANIZATION
  account_name      = var.SNOWFLAKE_ACCOUNT
  user              = var.SNOWFLAKE_USER
  role              = var.SNOWFLAKE_ROLE
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = var.SNOWFLAKE_PRIVATE_KEY
  warehouse         = var.SNOWFLAKE_WAREHOUSE
}

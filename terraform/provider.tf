terraform {
  required_version = "~> 1.13.0"
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

# USERADMINロール用のエイリアス（ユーザー管理専用）
provider "snowflake" {
  alias             = "user_admin"
  organization_name = var.SNOWFLAKE_ORGANIZATION
  account_name      = var.SNOWFLAKE_ACCOUNT
  user              = var.SNOWFLAKE_USER
  role              = "USERADMIN"
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = var.SNOWFLAKE_PRIVATE_KEY
  warehouse         = var.SNOWFLAKE_WAREHOUSE
}

# SECURITYADMINロール用のエイリアス（ロール・権限管理専用）
provider "snowflake" {
  alias             = "security_admin"
  organization_name = var.SNOWFLAKE_ORGANIZATION
  account_name      = var.SNOWFLAKE_ACCOUNT
  user              = var.SNOWFLAKE_USER
  role              = "SECURITYADMIN"
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = var.SNOWFLAKE_PRIVATE_KEY
  warehouse         = var.SNOWFLAKE_WAREHOUSE
}

# SYSADMINロール用のエイリアス（データベース・ウェアハウス管理専用）
provider "snowflake" {
  alias             = "sysadmin"
  organization_name = var.SNOWFLAKE_ORGANIZATION
  account_name      = var.SNOWFLAKE_ACCOUNT
  user              = var.SNOWFLAKE_USER
  role              = "SYSADMIN"
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = var.SNOWFLAKE_PRIVATE_KEY
  warehouse         = var.SNOWFLAKE_WAREHOUSE
}

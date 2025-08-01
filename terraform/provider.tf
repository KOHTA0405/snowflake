terraform {
  required_version = "~> 1.11.0"
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.3.0"
    }
  }
  backend "s3" {
    bucket = "terraform-state-manage-kohta"
    region = "ap-northeast-1"
    # key          = format("snowflake/%s/terraform.tfstate", var.ENVIRONMENT)
    use_lockfile = true
  }
}

provider "snowflake" {
  organization_name = var.SNOWFLAKE_ORGANIZATION
  account_name      = var.SNOWFLAKE_ACCOUNT
  user              = var.SNOWFLAKE_USER
  password          = var.SNOWFLAKE_PASSWORD
  role              = var.SNOWFLAKE_ROLE
}

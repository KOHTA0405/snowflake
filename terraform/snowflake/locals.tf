# 環境設定と共通設定
locals {
  environment = terraform.workspace
  iceberg_storage = contains(["dev", "prd"], local.environment) ? {
    bucket      = "kohta-snowflake-iceberg-${local.environment}"
    role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/snowflake-iceberg-${local.environment}"
    external_id = uuidv5("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "${data.aws_caller_identity.current.account_id}:snowflake-iceberg:${local.environment}")
  } : null

  environment_defaults = {
    warehouse_size       = "XSMALL"
    warehouse_generation = "2" # Gen2 for improved performance
    auto_suspend_seconds = 300
    auto_resume          = true
    initially_suspended  = true
    warehouse_comment    = null
  }

  environment_overrides = {
    dev = {
      warehouse_size       = "XSMALL"
      auto_suspend_seconds = 60
    }
    prd = {
      warehouse_size       = "SMALL"
      auto_suspend_seconds = 300
    }
  }

  environment_config = merge(
    local.environment_defaults,
    lookup(local.environment_overrides, local.environment, {})
  )
}

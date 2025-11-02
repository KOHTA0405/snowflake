locals {
  environment = terraform.workspace

  environment_defaults = {
    warehouse_size       = "XSMALL"
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

  warehouse = {
    name                = "dbt_${local.environment}_wh"
    size                = local.environment_config.warehouse_size
    auto_suspend        = local.environment_config.auto_suspend_seconds
    auto_resume         = local.environment_config.auto_resume
    initially_suspended = local.environment_config.initially_suspended
    comment = coalesce(
      local.environment_config.warehouse_comment,
      "warehouse for dbt ${local.environment} workloads"
    )
  }

  database = {
    name    = "${local.environment}"
    comment = "database for dbt ${local.environment}"
  }

  account_roles = [
    for role_name in ["administrator", "developer", "analyst"] : {
      name    = "${role_name}_${local.environment}"
      comment = "${local.environment} ${role_name} role for account"
    }
  ]

  database_role = {
    "write" = {
      name    = "write_${local.environment}"
      comment = "write role for ${local.environment} database"
    }
    "create_schema" = {
      name    = "create_schema_${local.environment}"
      comment = "create_schema role for ${local.environment} database"
    }
    "read" = {
      name    = "read_${local.environment}"
      comment = "read role for ${local.environment} database"
    }
  }

  privileges_to_database = ["USAGE"]

  user = {
    name    = "dbt_${local.environment}_user"
    comment = "user for dbt ${local.environment}"
  }

  schemas = [
    for schema_name in ["bronze", "silver", "gold"] : {
      name     = schema_name
      database = local.database.name
      comment  = "${schema_name} schema for dbt ${local.environment}"
    }
  ]

}

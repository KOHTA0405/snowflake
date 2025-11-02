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

  # account_roles = [
  #   for role_name in ["administrator", "developer", "analyst"] : {
  #     name    = "${role_name}_${local.environment}"
  #     comment = "${local.environment} ${role_name} role for account"
  #   }
  # ]
  account_role = {
    "administrator" = {
      name    = "administrator_${local.environment}"
      comment = "administrator role for ${local.environment} environment"
    }
    "developer" = {
      name    = "developer_${local.environment}"
      comment = "developer role for ${local.environment} environment"
    }
    "analyst" = {
      name    = "analyst_${local.environment}"
      comment = "analyst role for ${local.environment} environment"
    }
  }

  database_role = {
    "write" = {
      name    = "write_${local.environment}"
      comment = "write role for ${local.environment} database"
    }
    "change_schema" = {
      name    = "change_schema_${local.environment}"
      comment = "change_schema role for ${local.environment} database"
    }
    "read" = {
      name    = "read_${local.environment}"
      comment = "read role for ${local.environment} database"
    }
  }

  database_roles_for_developer = {
    for k, v in local.database_role : k => v
    if contains(["create_schema", "read"], k)
  }

  database_roles_for_analyst = {
    for k, v in local.database_role : k => v
    if contains(["read"], k)
  }

  user = {
    name    = "dbt_${local.environment}_user"
    comment = "user for dbt ${local.environment}"
  }

  privileges_to_database_role = {
    "write" = [
      "SELECT",
      "INSERT",
      "UPDATE",
      "DELETE",
      "TRUNCATE"
    ]

    "change_schema" = [
      "CREATE TABLE",
      "ALTER TABLE",
      "DROP TABLE",
      "CREATE VIEW",
      "ALTER VIEW",
      "DROP VIEW"
    ]

    "read" = [
      "SELECT"
    ]
  }

  schema = {
    "bronze" = {
      name     = "bronze"
      database = local.database.name
      comment  = "bronze schema for dbt ${local.environment}"
    }
    "silver" = {
      name     = "silver"
      database = local.database.name
      comment  = "silver schema for dbt ${local.environment}"
    }
    "gold" = {
      name     = "gold"
      database = local.database.name
      comment  = "gold schema for dbt ${local.environment}"
    }
  }

}

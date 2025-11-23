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
    name                = "DBT_${upper(local.environment)}_WH"
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
    name    = upper(local.environment)
    comment = "database for dbt ${local.environment}"
  }

  account_role = {
    "administrator" = {
      name    = "ADMINISTRATOR_${upper(local.environment)}"
      comment = "administrator role for ${local.environment} environment"
    }
    "developer" = {
      name    = "DEVELOPER_${upper(local.environment)}"
      comment = "developer role for ${local.environment} environment"
    }
    "analyst" = {
      name    = "ANALYST_${upper(local.environment)}"
      comment = "analyst role for ${local.environment} environment"
    }
  }

  database_role = {
    "write" = {
      name    = "WRITE_${upper(local.environment)}"
      comment = "write role for ${local.environment} database"
    }
    "change_schema" = {
      name    = "CHANGE_SCHEMA_${upper(local.environment)}"
      comment = "change_schema role for ${local.environment} database"
    }
    "read" = {
      name    = "READ_${upper(local.environment)}"
      comment = "read role for ${local.environment} database"
    }
  }

  database_roles_for_developer = {
    for k, v in local.database_role : k => v
    if contains(["change_schema", "read"], k)
  }

  database_roles_for_analyst = {
    for k, v in local.database_role : k => v
    if contains(["read"], k)
  }

  user = {
    name    = "DBT_${upper(local.environment)}_USER"
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
      "USAGE",
      "CREATE TABLE",
      "CREATE VIEW",
      "CREATE FILE FORMAT",
      "CREATE STAGE",
      "CREATE FUNCTION",
      "CREATE PROCEDURE",
      "CREATE SEQUENCE",
      "CREATE PIPE",
      "CREATE STREAM",
      "CREATE TASK",
      "CREATE SNAPSHOT"
    ]

    "read" = [
      "SELECT"
    ]
  }

  schema = {
    "bronze" = {
      name     = "BRONZE"
      database = local.database.name
      comment  = "bronze schema for dbt ${local.environment}"
    }
    "silver" = {
      name     = "SILVER"
      database = local.database.name
      comment  = "silver schema for dbt ${local.environment}"
    }
    "gold" = {
      name     = "GOLD"
      database = local.database.name
      comment  = "gold schema for dbt ${local.environment}"
    }
  }

}

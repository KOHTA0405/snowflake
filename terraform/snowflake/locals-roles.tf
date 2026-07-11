# Account RoleとDatabase Role関連のlocals
locals {
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
    "lightdash" = {
      name    = "LIGHTDASH_${upper(local.environment)}"
      comment = "lightdash role for ${local.environment} environment"
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

  database_roles_for_lightdash = {
    for k, v in local.database_role : k => v
    if contains(["read"], k)
  }
}


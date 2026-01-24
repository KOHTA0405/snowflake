# Grant schema USAGE privilege to database roles
module "grant_privileges_to_schema_role" {
  source   = "./modules/grant_database_role/privileges_for_schema"
  for_each = local.database_role

  database_role_name = module.database_roles[each.key].database_role_fully_qualified_name
  privilege_list     = ["USAGE"]
  database_name      = local.database.name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant privileges to write database_role for all schemas
module "grant_privileges_to_write_role" {
  source   = "./modules/grant_database_role/privileges_for_schema_object"
  for_each = local.schema

  database_role_name = module.database_roles["write"].database_role_fully_qualified_name
  privilege_list     = local.privileges_to_database_role["write"]
  object_type        = "TABLES"
  schema_name        = module.schemas[each.key].schema_fully_qualified_name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant privileges to change_schema database_role for all schemas
module "grant_privileges_to_change_schema_role" {
  source   = "./modules/grant_database_role/privileges_for_schema"
  for_each = local.schema

  database_role_name = module.database_roles["change_schema"].database_role_fully_qualified_name
  privilege_list     = local.privileges_to_database_role["change_schema"]
  database_name      = local.database.name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant table privileges to read database_role for all schemas
module "grant_table_privileges_to_read_role" {
  source   = "./modules/grant_database_role/privileges_for_schema_object"
  for_each = local.schema

  database_role_name = module.database_roles["read"].database_role_fully_qualified_name
  privilege_list     = local.privileges_to_database_role["read"]
  object_type        = "TABLES"
  schema_name        = module.schemas[each.key].schema_fully_qualified_name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant view privileges to read database_role for all schemas
module "grant_view_privileges_to_read_role" {
  source   = "./modules/grant_database_role/privileges_for_schema_object"
  for_each = local.schema

  database_role_name = module.database_roles["read"].database_role_fully_qualified_name
  privilege_list     = local.privileges_to_database_role["read"]
  object_type        = "VIEWS"
  schema_name        = module.schemas[each.key].schema_fully_qualified_name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant database roles to administrator_role
module "grant_database_role_to_account_role" {
  source   = "./modules/grant_database_role/database_role_to_account_role"
  for_each = local.database_role

  database_role_name = module.database_roles[each.key].database_role_fully_qualified_name
  parent_role_name   = local.account_role["administrator"].name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant database roles to developer_role
module "grant_database_role_to_developer_role" {
  source   = "./modules/grant_database_role/database_role_to_account_role"
  for_each = local.database_roles_for_developer

  database_role_name = module.database_roles[each.key].database_role_fully_qualified_name
  parent_role_name   = local.account_role["developer"].name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant database roles to analyst_role
module "grant_database_role_to_analyst_role" {
  source   = "./modules/grant_database_role/database_role_to_account_role"
  for_each = local.database_roles_for_analyst

  database_role_name = module.database_roles[each.key].database_role_fully_qualified_name
  parent_role_name   = local.account_role["analyst"].name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant database roles to lightdash_role
module "grant_database_role_to_lightdash_role" {
  source   = "./modules/grant_database_role/database_role_to_account_role"
  for_each = local.database_roles_for_lightdash

  database_role_name = module.database_roles[each.key].database_role_fully_qualified_name
  parent_role_name   = local.account_role["lightdash"].name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant SNOWFLAKE database roles to administrator_role for ACCOUNT_USAGE and ORGANIZATION_USAGE access
# These are pre-existing system-defined database roles in the SNOWFLAKE database
# USAGE_VIEWER: Access to historical usage information (ACCOUNT_USAGE views)
# OBJECT_VIEWER: Access to object metadata (ACCOUNT_USAGE views)
# These roles provide access to ACCOUNT_USAGE and ORGANIZATION_USAGE schemas

# Grant USAGE_VIEWER database role for usage and billing information
module "grant_snowflake_usage_viewer_to_administrator_role" {
  source     = "./modules/grant_database_role/database_role_to_account_role"
  depends_on = [module.account_roles]

  database_role_name = "\"SNOWFLAKE\".\"USAGE_VIEWER\""
  parent_role_name   = local.account_role["administrator"].name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant OBJECT_VIEWER database role for object metadata
module "grant_snowflake_object_viewer_to_administrator_role" {
  source     = "./modules/grant_database_role/database_role_to_account_role"
  depends_on = [module.account_roles]

  database_role_name = "\"SNOWFLAKE\".\"OBJECT_VIEWER\""
  parent_role_name   = local.account_role["administrator"].name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# output "test" {
#   value = {
#     for k, v in local.database_role : k => v
#     if contains(["write", "create_schema"], k)
#   }
# }


# output "test" {
#   value = local.for_developer_database_roles
# }

# output "test" {
#   value = module.schemas
# }

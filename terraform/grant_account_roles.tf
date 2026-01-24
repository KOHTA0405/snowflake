module "grant_account_role_to_sysadmin" {
  source     = "./modules/grant_account_role/account_role_to_sysadmin"
  for_each   = local.account_role
  depends_on = [module.account_roles]

  role_name = each.value.name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

module "grant_developer_role_to_kohta" {
  source     = "./modules/grant_account_role/account_role_to_user"
  depends_on = [module.account_roles, module.kohta_user]

  role_name = local.account_role["developer"].name
  user_name = module.kohta_user.name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

module "grant_administrator_role_to_dbt_user" {
  source     = "./modules/grant_account_role/account_role_to_user"
  depends_on = [module.account_roles, module.dbt_user]

  role_name = local.account_role["administrator"].name
  user_name = module.dbt_user.name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant database USAGE privilege to account roles
module "grant_database_usage_to_account_roles" {
  source   = "./modules/grant_account_role/privileges_for_database"
  for_each = local.account_role

  account_role_name = module.account_roles[each.key].name
  privilege_list    = ["USAGE"]
  database_name     = local.database.name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant warehouse USAGE privilege to account roles
module "grant_warehouse_usage_to_account_roles" {
  source   = "./modules/grant_account_role/privileges_for_warehouse"
  for_each = local.account_role

  account_role_name = module.account_roles[each.key].name
  privilege_list    = ["USAGE"]
  warehouse_name    = module.dbt_warehouse.name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant lightdash role to lightdash user
module "grant_lightdash_role_to_lightdash_user" {
  source     = "./modules/grant_account_role/account_role_to_user"
  depends_on = [module.account_roles, module.lightdash_user]

  role_name = local.account_role["lightdash"].name
  user_name = module.lightdash_user.name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant database USAGE privilege to lightdash role
module "grant_database_usage_to_lightdash_role" {
  source     = "./modules/grant_account_role/privileges_for_database"
  depends_on = [module.account_roles]

  account_role_name = module.account_roles["lightdash"].name
  privilege_list    = ["USAGE"]
  database_name     = local.database.name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant warehouse USAGE privilege to lightdash role
module "grant_warehouse_usage_to_lightdash_role" {
  source     = "./modules/grant_account_role/privileges_for_warehouse"
  depends_on = [module.account_roles, module.lightdash_warehouse]

  account_role_name = module.account_roles["lightdash"].name
  privilege_list    = ["USAGE"]
  warehouse_name    = module.lightdash_warehouse.name

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

# Grant IMPORTED PRIVILEGES on SNOWFLAKE database to administrator role
# Required for accessing ACCOUNT_USAGE and ORGANIZATION_USAGE schemas
# SNOWFLAKE is an imported database, so we must use IMPORTED PRIVILEGES instead of individual privileges
resource "snowflake_grant_privileges_to_account_role" "grant_snowflake_imported_privileges_to_administrator_role" {
  provider          = snowflake.security_admin
  account_role_name = module.account_roles["administrator"].name
  privileges        = ["IMPORTED PRIVILEGES"]
  on_account_object {
    object_type = "DATABASE"
    object_name = "SNOWFLAKE"
  }
}

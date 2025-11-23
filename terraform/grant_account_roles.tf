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

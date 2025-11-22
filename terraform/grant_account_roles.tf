module "grant_account_role_to_sysadmin" {
  source     = "./modules/grant_account_role/account_role_to_sysadmin"
  for_each   = local.account_role
  depends_on = [module.account_roles]

  role_name = each.value.name
}

module "grant_developer_role_to_kohta" {
  source     = "./modules/grant_account_role/account_role_to_user"
  depends_on = [module.account_roles, module.kohta_user]

  role_name = local.account_role["developer"].name
  user_name = module.kohta_user.name
}

module "grant_administrator_role_to_dbt_user" {
  source     = "./modules/grant_account_role/account_role_to_user"
  depends_on = [module.account_roles, module.dbt_user]

  role_name = local.account_role["administrator"].name
  user_name = module.dbt_user.name
}

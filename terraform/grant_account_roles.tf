module "grant_account_role_to_sysadmin" {
  source    = "./modules/grant_account_role/account_role_to_sysadmin"
  for_each  = local.account_role
  role_name = each.value.name
}

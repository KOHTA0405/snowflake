module "account_roles" {
  source   = "./modules/account_role"
  for_each = local.account_role

  name    = each.value.name
  comment = each.value.comment

  providers = {
    snowflake.security_admin = snowflake.security_admin
  }
}

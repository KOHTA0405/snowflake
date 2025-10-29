module "account_roles" {
  for_each = { for account_role in local.account_roles : account_role.name => account_role }
  source   = "./modules/account_role"

  name    = each.value.name
  comment = each.value.comment

}

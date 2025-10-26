module "dbt_account_role" {
  source = "./modules/account_role"

  name    = local.account_role.name
  comment = local.account_role.comment

}

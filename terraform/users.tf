module "dbt_user" {
  source = "./modules/user"

  name    = local.user.name
  comment = local.user.comment
}

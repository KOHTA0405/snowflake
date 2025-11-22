module "dbt_user" {
  source = "./modules/user"

  name    = local.user.name
  comment = local.user.comment
}

module "kohta_user" {
  source = "./modules/user"

  name    = "KOHTA"
  comment = "User for KOHTA"
}

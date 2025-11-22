module "dbt_user" {
  source = "./modules/user"

  name    = local.user.name
  comment = local.user.comment

  providers = {
    snowflake.user_admin = snowflake.user_admin
  }
}

module "kohta_user" {
  source = "./modules/user"

  name    = "KOHTA"
  comment = "User for KOHTA"

  providers = {
    snowflake.user_admin = snowflake.user_admin
  }
}

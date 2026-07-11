module "dbt_user" {
  source = "./modules/user"

  name           = local.user.name
  comment        = local.user.comment
  rsa_public_key = var.DBT_USER_RSA_PUBLIC_KEY

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

module "lightdash_user" {
  source = "./modules/user"

  name           = local.lightdash_user.name
  comment        = local.lightdash_user.comment
  rsa_public_key = var.LIGHTDASH_USER_RSA_PUBLIC_KEY

  providers = {
    snowflake.user_admin = snowflake.user_admin
  }
}

module "database" {
  source = "./modules/database"

  name    = local.database.name
  comment = local.database.comment

  providers = {
    snowflake.sysadmin = snowflake.sysadmin
  }
}

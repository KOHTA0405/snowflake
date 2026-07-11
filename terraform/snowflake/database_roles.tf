module "database_roles" {
  source   = "./modules/database_role"
  for_each = local.database_role

  database_name = module.database.name
  name          = each.value.name
  comment       = each.value.comment

  providers = {
    snowflake.sysadmin = snowflake.sysadmin
  }
}

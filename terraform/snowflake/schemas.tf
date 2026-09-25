module "schemas" {
  source   = "./modules/schema"
  for_each = local.schema

  database                     = module.database.name
  name                         = each.value.name
  comment                      = each.value.comment
  storage_serialization_policy = each.key == "gold" && local.iceberg_storage != null ? "COMPATIBLE" : null

  providers = {
    snowflake.sysadmin = snowflake.sysadmin
  }
}

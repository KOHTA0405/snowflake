module "schemas" {
  source   = "./modules/schema"
  for_each = local.schema

  database                     = module.database.name
  name                         = each.value.name
  comment                      = each.value.comment
  external_volume              = each.key == "gold" && local.iceberg_storage != null ? snowflake_external_volume.iceberg[local.environment].name : null
  storage_serialization_policy = each.key == "gold" && local.iceberg_storage != null ? "COMPATIBLE" : null

  providers = {
    snowflake.sysadmin = snowflake.sysadmin
  }
}

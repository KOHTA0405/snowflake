resource "snowflake_schema" "this" {
  provider                     = snowflake.sysadmin
  database                     = var.database
  name                         = var.name
  comment                      = var.comment
  external_volume              = var.external_volume
  storage_serialization_policy = var.storage_serialization_policy
}

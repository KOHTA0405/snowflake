resource "snowflake_schema" "this" {
  provider = snowflake.sysadmin
  database = var.database
  name     = var.name
  comment  = var.comment
}

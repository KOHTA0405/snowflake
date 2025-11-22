resource "snowflake_database_role" "this" {
  provider = snowflake.sysadmin
  database = var.database_name
  name     = var.name
  comment  = var.comment
}

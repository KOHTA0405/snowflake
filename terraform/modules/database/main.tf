resource "snowflake_database" "this" {
  provider = snowflake.sysadmin
  name     = var.name
  comment  = var.comment
}

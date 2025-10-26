resource "snowflake_database_role" "this" {
  database = var.database_name
  name     = var.name
  comment  = var.comment
}

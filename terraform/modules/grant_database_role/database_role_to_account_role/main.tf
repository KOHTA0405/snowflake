resource "snowflake_grant_database_role" "this" {
  provider           = snowflake.security_admin
  database_role_name = var.database_role_name
  parent_role_name   = var.parent_role_name

  lifecycle {
    ignore_changes = [id]
  }
}

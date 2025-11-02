resource "snowflake_grant_privileges_to_database_role" "this" {
  database_role_name = var.database_role_name
  privileges         = var.privilege_list
  on_schema {
    schema_name = var.schema_name
  }
}

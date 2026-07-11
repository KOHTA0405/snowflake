# Grant privileges on all existing schemas in database
resource "snowflake_grant_privileges_to_database_role" "this" {
  provider           = snowflake.security_admin
  database_role_name = var.database_role_name
  privileges         = var.privilege_list
  on_schema {
    all_schemas_in_database = var.database_name
  }
}

# Grant privileges on future schemas in database
resource "snowflake_grant_privileges_to_database_role" "future" {
  provider           = snowflake.security_admin
  database_role_name = var.database_role_name
  privileges         = var.privilege_list
  on_schema {
    future_schemas_in_database = var.database_name
  }
}

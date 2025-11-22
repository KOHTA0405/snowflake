# Grant privileges on existing objects
resource "snowflake_grant_privileges_to_database_role" "this" {
  provider           = snowflake.security_admin
  database_role_name = var.database_role_name
  privileges         = var.privilege_list
  on_schema_object {
    all {
      object_type_plural = var.object_type
      in_schema          = var.schema_name
    }
  }
}

# Grant privileges on future objects
resource "snowflake_grant_privileges_to_database_role" "future" {
  provider           = snowflake.security_admin
  database_role_name = var.database_role_name
  privileges         = var.privilege_list
  on_schema_object {
    future {
      object_type_plural = var.object_type
      in_schema          = var.schema_name
    }
  }
}

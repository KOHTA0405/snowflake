resource "snowflake_grant_privileges_to_account_role" "this" {
  provider          = snowflake.security_admin
  account_role_name = var.account_role_name
  privileges        = var.privilege_list
  on_schema_object {
    all {
      object_type_plural = var.object_type_plural
      in_schema          = var.schema_fully_qualified_name
    }
  }
}

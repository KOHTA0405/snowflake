resource "snowflake_grant_privileges_to_account_role" "this" {
  provider          = snowflake.security_admin
  account_role_name = var.account_role_name
  privileges        = var.privilege_list
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = var.warehouse_name
  }
}


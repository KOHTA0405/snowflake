resource "snowflake_grant_account_role" "this" {
  provider         = snowflake.security_admin
  role_name        = var.role_name
  parent_role_name = "SYSADMIN"
}

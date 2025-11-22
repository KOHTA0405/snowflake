resource "snowflake_grant_account_role" "this" {
  role_name = var.role_name
  user_name = var.user_name
}


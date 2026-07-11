resource "snowflake_account_role" "this" {
  provider = snowflake.security_admin
  name     = var.name
  comment  = var.comment
}

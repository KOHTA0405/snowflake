resource "snowflake_user" "this" {
  provider = snowflake.user_admin
  name     = var.name
  comment  = var.comment
}

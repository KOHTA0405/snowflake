resource "snowflake_account_role" "this" {
  name    = var.name
  comment = var.comment
}

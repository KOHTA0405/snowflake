resource "snowflake_user" "this" {
  name    = var.name
  comment = var.comment
}

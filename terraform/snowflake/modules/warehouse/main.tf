resource "snowflake_warehouse" "this" {
  provider            = snowflake.sysadmin
  name                = var.name
  warehouse_size      = var.size
  warehouse_type      = "STANDARD"
  generation          = var.generation != null ? var.generation : null
  auto_suspend        = var.auto_suspend
  auto_resume         = var.auto_resume
  initially_suspended = var.initially_suspended
  comment             = var.comment
}

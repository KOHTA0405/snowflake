resource "snowflake_warehouse" "this" {
  provider            = snowflake.sysadmin
  name                = var.name
  warehouse_size      = var.size
  auto_suspend        = var.auto_suspend
  auto_resume         = var.auto_resume
  initially_suspended = var.initially_suspended
  comment             = var.comment
}

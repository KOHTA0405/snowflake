resource "snowflake_warehouse" "this" {
  name                = var.name
  warehouse_size      = var.size
  auto_suspend        = var.auto_suspend
  auto_resume         = var.auto_resume
  initially_suspended = var.initially_suspended
  comment             = var.comment
}

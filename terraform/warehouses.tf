module "dbt_warehouse" {
  source = "./modules/warehouse"

  name                = local.warehouse.name
  size                = local.warehouse.size
  auto_suspend        = local.warehouse.auto_suspend
  auto_resume         = local.warehouse.auto_resume
  initially_suspended = local.warehouse.initially_suspended
  comment             = local.warehouse.comment
}

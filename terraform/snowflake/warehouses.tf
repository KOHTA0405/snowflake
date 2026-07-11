module "dbt_warehouse" {
  source = "./modules/warehouse"

  name                = local.warehouse.name
  size                = local.warehouse.size
  generation          = local.warehouse.generation
  auto_suspend        = local.warehouse.auto_suspend
  auto_resume         = local.warehouse.auto_resume
  initially_suspended = local.warehouse.initially_suspended
  comment             = local.warehouse.comment

  providers = {
    snowflake.sysadmin = snowflake.sysadmin
  }
}

module "lightdash_warehouse" {
  source = "./modules/warehouse"

  name                = local.lightdash_warehouse.name
  size                = local.lightdash_warehouse.size
  generation          = local.lightdash_warehouse.generation
  auto_suspend        = local.lightdash_warehouse.auto_suspend
  auto_resume         = local.lightdash_warehouse.auto_resume
  initially_suspended = local.lightdash_warehouse.initially_suspended
  comment             = local.lightdash_warehouse.comment

  providers = {
    snowflake.sysadmin = snowflake.sysadmin
  }
}

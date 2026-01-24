# Warehouse関連のlocals
locals {
  warehouse = {
    name                = "DBT_${upper(local.environment)}_WH"
    size                = local.environment_config.warehouse_size
    generation          = local.environment_config.warehouse_generation
    auto_suspend        = local.environment_config.auto_suspend_seconds
    auto_resume         = local.environment_config.auto_resume
    initially_suspended = local.environment_config.initially_suspended
    comment = coalesce(
      local.environment_config.warehouse_comment,
      "warehouse for dbt ${local.environment} workloads"
    )
  }

  lightdash_warehouse = {
    name                = "LIGHTDASH_${upper(local.environment)}_WH"
    size                = local.environment_config.warehouse_size
    generation          = local.environment_config.warehouse_generation
    auto_suspend        = local.environment_config.auto_suspend_seconds
    auto_resume         = local.environment_config.auto_resume
    initially_suspended = local.environment_config.initially_suspended
    comment = coalesce(
      local.environment_config.warehouse_comment,
      "warehouse for lightdash ${local.environment} workloads"
    )
  }
}


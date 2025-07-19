resource "snowflake_warehouse" "dbt_wh" {
  name           = format("%s_dbt_wh", var.ENVIRONMENT)
  warehouse_size = "XSMALL"
  auto_suspend   = 60
}

resource "snowflake_warehouse" "dbt_wh" {
  name           = "DBT_WH"
  warehouse_size = "XSMALL"
  auto_suspend   = 60
}

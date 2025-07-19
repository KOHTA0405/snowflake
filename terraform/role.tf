resource "snowflake_account_role" "dbt_admin_role" {
  name = format("%s_dbt_admin_role", var.ENVIRONMENT)
}

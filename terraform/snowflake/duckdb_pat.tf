resource "snowflake_user_programmatic_access_token" "duckdb_iceberg_dev" {
  count    = terraform.workspace == "dev" ? 1 : 0
  provider = snowflake.user_admin

  user                                      = module.kohta_user.name
  name                                      = "DUCKDB_ICEBERG_DEV"
  role_restriction                          = module.account_roles["developer"].name
  days_to_expiry                            = 7
  mins_to_bypass_network_policy_requirement = 60
  comment                                   = "Local DuckDB read access to dev Iceberg tables"

  depends_on = [module.grant_developer_role_to_kohta]
}

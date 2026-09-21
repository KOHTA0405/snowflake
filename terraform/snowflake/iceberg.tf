resource "snowflake_external_volume" "iceberg" {
  for_each = local.iceberg_storage == null ? {} : { (local.environment) = local.iceberg_storage }
  provider = snowflake.sysadmin

  name         = "ICEBERG_${upper(each.key)}"
  comment      = "Snowflake-managed Iceberg tables for ${each.key}"
  allow_writes = true

  storage_location {
    storage_location_name   = "s3-${each.key}"
    storage_provider        = "S3"
    storage_base_url        = "s3://${each.value.bucket}/tables/"
    storage_aws_role_arn    = each.value.role_arn
    storage_aws_external_id = each.value.external_id
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "snowflake_grant_privileges_to_account_role" "iceberg_dbt_usage" {
  for_each = snowflake_external_volume.iceberg
  provider = snowflake.sysadmin

  account_role_name = module.account_roles["administrator"].name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "EXTERNAL VOLUME"
    object_name = each.value.name
  }
}

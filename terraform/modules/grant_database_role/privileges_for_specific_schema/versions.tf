terraform {
  required_version = "~> 1.13.0"
  required_providers {
    snowflake = {
      source                = "snowflakedb/snowflake"
      version               = "~> 2.3.0"
      configuration_aliases = [snowflake.security_admin]
    }
  }
}

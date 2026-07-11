# Schema関連のlocals
locals {
  schema = {
    "bronze" = {
      name     = "BRONZE"
      database = local.database.name
      comment  = "bronze schema for dbt ${local.environment}"
    }
    "silver" = {
      name     = "SILVER"
      database = local.database.name
      comment  = "silver schema for dbt ${local.environment}"
    }
    "gold" = {
      name     = "GOLD"
      database = local.database.name
      comment  = "gold schema for dbt ${local.environment}"
    }
    "dbt_snowflake_monitoring" = {
      name     = "DBT_SNOWFLAKE_MONITORING"
      database = local.database.name
      comment  = "dbt snowflake monitoring schema for ${local.environment}"
    }
    "elementary" = {
      name     = "ELEMENTARY"
      database = local.database.name
      comment  = "elementary monitoring schema for ${local.environment}"
    }
  }
}


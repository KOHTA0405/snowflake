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
  }
}


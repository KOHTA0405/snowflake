# Database関連のlocals
locals {
  database = {
    name    = upper(local.environment)
    comment = "database for dbt ${local.environment}"
  }
}


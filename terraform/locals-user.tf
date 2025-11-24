# User関連のlocals
locals {
  user = {
    name    = "DBT_${upper(local.environment)}_USER"
    comment = "user for dbt ${local.environment}"
  }

  lightdash_user = {
    name    = "LIGHTDASH_${upper(local.environment)}_USER"
    comment = "user for lightdash ${local.environment}"
  }
}


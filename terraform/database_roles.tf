module "dbt_database_role" {
  source = "./modules/database_role"

  database_name = local.database.name
  name          = local.database_role.name
  comment       = local.database_role.comment
}

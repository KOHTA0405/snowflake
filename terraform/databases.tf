module "dbt_database" {
  source = "./modules/database"

  name    = local.database.name
  comment = local.database.comment
}

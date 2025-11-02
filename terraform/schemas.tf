module "dbt_schemas" {
  source   = "./modules/schema"
  for_each = local.schema

  database = local.database.name
  name     = each.value.name
  comment  = each.value.comment

  depends_on = [module.dbt_database]
}

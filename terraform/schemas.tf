module "dbt_schemas" {
  for_each = { for schema in local.schemas : schema.name => schema }
  source   = "./modules/schema"

  database = each.value.database
  name     = each.value.name
  comment  = each.value.comment

  depends_on = [module.dbt_database]
}

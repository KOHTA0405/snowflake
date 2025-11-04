module "schemas" {
  source   = "./modules/schema"
  for_each = local.schema

  database = module.database.name
  name     = each.value.name
  comment  = each.value.comment
}

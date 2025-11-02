module "database_roles" {
  source     = "./modules/database_role"
  for_each   = local.database_role
  depends_on = [module.database]

  database_name = local.database.name
  name          = each.value.name
  comment       = each.value.comment
}

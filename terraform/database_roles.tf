module "database_roles" {
  for_each = local.database_role
  source   = "./modules/database_role"

  database_name = local.database.name
  name          = each.value.name
  comment       = each.value.comment
}

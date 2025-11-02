module "database_roles" {
  source   = "./modules/database_role"
  for_each = local.database_role

  database_name = local.database.name
  name          = each.value.name
  comment       = each.value.comment
}

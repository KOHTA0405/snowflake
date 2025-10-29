module "database_roles" {
  for_each = { for database_role in local.database_roles : database_role.name => database_role }
  source   = "./modules/database_role"

  database_name = local.database.name
  name          = each.value.name
  comment       = each.value.comment
}

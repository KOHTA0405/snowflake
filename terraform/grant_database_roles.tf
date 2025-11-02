# Grant privileges to database roles
module "grant_privileges_to_database_role" {
  source   = "./modules/grant_database_role/privileges_to_database"
  for_each = local.database_role

  database_role_name = module.database_roles[each.key].database_role_fully_qualified_name
  privilege_list     = local.privileges_to_database
  database_name      = local.database.name
}

# Grant database roles to administrator_role
module "grant_database_role_to_account_role" {
  source   = "./modules/grant_database_role/databas_role_to_account_role"
  for_each = local.database_role

  database_role_name = module.database_roles[each.key].database_role_fully_qualified_name
  parent_role_name   = local.account_role["administrator"].name
}

# Grant database roles to developer_role
module "grant_database_role_to_developer_role" {
  source   = "./modules/grant_database_role/databas_role_to_account_role"
  for_each = local.for_developer_database_roles

  database_role_name = module.database_roles[each.key].database_role_fully_qualified_name
  parent_role_name   = local.account_role["developer"].name
}

# Grant database roles to analyst_role
module "grant_database_role_to_analyst_role" {
  source   = "./modules/grant_database_role/databas_role_to_account_role"
  for_each = local.for_analyst_database_roles

  database_role_name = module.database_roles[each.key].database_role_fully_qualified_name
  parent_role_name   = local.account_role["analyst"].name
}

# output "test" {
#   value = {
#     for k, v in local.database_role : k => v
#     if contains(["write", "create_schema"], k)
#   }
# }


# output "test" {
#   value = local.for_developer_database_roles
# }

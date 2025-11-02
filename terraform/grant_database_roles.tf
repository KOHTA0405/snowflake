# module "grant_privileges_to_database_role" {
#   source = "./modules/grant_database_role/privileges_to_database"
#   # for_each = local.database_role

#   database_role_name = module.database_roles.name.fully_qualified_name
#   privilege_list     = local.privileges_to_database
#   database_name      = local.database.name
# }

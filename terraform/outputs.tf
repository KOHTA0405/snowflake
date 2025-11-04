# Database
output "database_name" {
  description = "Database name"
  value       = module.database.name
}

# Schemas
output "schema_names" {
  description = "Schema names by key"
  value       = { for k, m in module.schemas : k => m.name }
}

output "schema_fqns" {
  description = "Schema fully qualified names by key"
  value       = { for k, m in module.schemas : k => m.schema_fully_qualified_name }
}

# Database roles
output "database_role_names" {
  description = "Database role names by key"
  value       = { for k, m in module.database_roles : k => m.name }
}

output "database_role_fqns" {
  description = "Database role FQNs by key"
  value       = { for k, m in module.database_roles : k => m.database_role_fully_qualified_name }
}

# Account roles
output "account_role_names" {
  description = "Account role names by key"
  value       = { for k, m in module.account_roles : k => m.name }
}

# Warehouse / User
output "warehouse_name" {
  description = "Warehouse name"
  value       = module.dbt_warehouse.name
}

output "dbt_user_name" {
  description = "DBT user name"
  value       = module.dbt_user.name
}



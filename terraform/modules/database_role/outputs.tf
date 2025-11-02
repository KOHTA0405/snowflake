output "name" {
  description = "The name of the database role."
  value       = snowflake_database_role.this.name
}

output "database_role_fully_qualified_name" {
  value = snowflake_database_role.this.fully_qualified_name
}

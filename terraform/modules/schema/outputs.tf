output "name" {
  description = "Schema name."
  value       = snowflake_schema.this.name
}

output "schema_fully_qualified_name" {
  description = "Schema fully qualified name."
  value       = snowflake_schema.this.fully_qualified_name
}

variable "database_role_name" {
  description = "Name of the database role to grant privileges."
  type        = string
}

variable "privilege_list" {
  description = "List of privileges to grant."
  type        = list(string)
  default     = []
}

variable "schema_name" {
  description = "Fully qualified name of the schema (e.g., SNOWFLAKE.ACCOUNT_USAGE)"
  type        = string
}

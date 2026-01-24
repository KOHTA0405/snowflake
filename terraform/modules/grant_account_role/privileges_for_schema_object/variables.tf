variable "account_role_name" {
  description = "The name of the account role to grant privileges to"
  type        = string
}

variable "privilege_list" {
  description = "List of privileges to grant"
  type        = list(string)
}

variable "object_type_plural" {
  description = "Plural type of object (VIEWS, TABLES, etc.)"
  type        = string
}

variable "schema_fully_qualified_name" {
  description = "Fully qualified name of the schema (e.g., SNOWFLAKE.ACCOUNT_USAGE)"
  type        = string
}

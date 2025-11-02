variable "database_role_name" {
  description = "Name of the database role to grant privileges."
  type        = string
}

variable "privilege_list" {
  description = "List of privileges to grant."
  type        = list(string)
  default     = []
}

variable "object_type" {
  description = "Type of schema object to grant privileges on (e.g., TABLES, VIEWS)."
  type        = string
}

variable "schema_name" {
  description = "Name of the schema containing the objects."
  type        = string
}

variable "database_role_name" {
  description = "Name of the database role to grant privileges to."
  type        = string
}

variable "privilege_list" {
  description = "List of privileges to grant."
  type        = list(string)
  default     = []
}

variable "database_name" {
  description = "Name of the database."
  type        = string
  default     = "dev"
}

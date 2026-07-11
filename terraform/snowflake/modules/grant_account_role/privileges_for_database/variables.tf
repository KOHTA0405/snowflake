variable "account_role_name" {
  description = "The name of the account role to grant privileges to"
  type        = string
}

variable "privilege_list" {
  description = "List of privileges to grant"
  type        = list(string)
}

variable "database_name" {
  description = "The name of the database"
  type        = string
}


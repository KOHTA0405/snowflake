variable "database_name" {
  description = "The name of the database."
  type        = string
}

variable "name" {
  description = "The name of the database role."
  type        = string
}

variable "comment" {
  description = "The comment for the database role."
  type        = string
  default     = null
}

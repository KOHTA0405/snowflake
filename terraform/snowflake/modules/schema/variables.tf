variable "database" {
  description = "Database that owns the schema."
  type        = string
}

variable "name" {
  description = "Schema name."
  type        = string
}

variable "comment" {
  description = "Optional schema comment."
  type        = string
  default     = null
}

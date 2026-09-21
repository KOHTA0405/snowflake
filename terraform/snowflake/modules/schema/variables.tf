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

variable "external_volume" {
  description = "Default external volume for Iceberg tables in this schema."
  type        = string
  default     = null
}

variable "storage_serialization_policy" {
  description = "Default Iceberg storage serialization policy."
  type        = string
  default     = null
}

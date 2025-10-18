variable "name" {
  description = "Database name."
  type        = string
}

variable "comment" {
  description = "Optional database comment."
  type        = string
  default     = null
}

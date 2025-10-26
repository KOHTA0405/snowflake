variable "name" {
  description = "The name of the user."
  type        = string
}

variable "comment" {
  description = "Optional comment for the user."
  type        = string
  default     = null
}

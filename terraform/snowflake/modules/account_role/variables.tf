variable "name" {
  description = "The name of the account role."
  type        = string
}

variable "comment" {
  description = "Optional comment for the account role. "
  type        = string
  default     = null
}

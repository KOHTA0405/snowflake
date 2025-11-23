variable "name" {
  description = "The name of the user."
  type        = string
}

variable "comment" {
  description = "Optional comment for the user."
  type        = string
  default     = null
}

variable "rsa_public_key" {
  description = "RSA public key for key-pair authentication. Must be on 1 line without header and trailer."
  type        = string
  default     = null
  sensitive   = true
}

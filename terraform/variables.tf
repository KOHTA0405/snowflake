variable "SNOWFLAKE_ORGANIZATION" {
  description = "Snowflake organization name"
  type        = string
}

variable "SNOWFLAKE_ACCOUNT" {
  description = "Snowflake account name"
  type        = string
}

variable "SNOWFLAKE_USER" {
  description = "Snowflake user"
  type        = string
}

variable "SNOWFLAKE_ROLE" {
  description = "Snowflake role"
  type        = string
}

variable "SNOWFLAKE_PRIVATE_KEY_PATH" {
  description = "Path to the Snowflake private key file"
  type        = string
  default     = ""
}

variable "SNOWFLAKE_PRIVATE_KEY_PASSPHRASE" {
  description = "Passphrase for the Snowflake private key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "SNOWFLAKE_WAREHOUSE" {
  description = "Snowflake warehouse"
  type        = string
}

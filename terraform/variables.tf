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

variable "SNOWFLAKE_PRIVATE_KEY" {
  description = "Snowflake private key content"
  type        = string
  sensitive   = true
}

variable "SNOWFLAKE_WAREHOUSE" {
  description = "Snowflake warehouse"
  type        = string
}

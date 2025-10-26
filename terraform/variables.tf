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

variable "SNOWFLAKE_PRIVATE_KEY" {
  description = "Snowflake private key content"
  type        = string
  default     = ""
}

variable "SNOWFLAKE_WAREHOUSE" {
  description = "Snowflake warehouse"
  type        = string
}

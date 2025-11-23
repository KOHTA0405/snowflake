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

variable "DBT_USER_RSA_PUBLIC_KEY" {
  description = "RSA public key for dbt user. Must be on 1 line without header and trailer."
  type        = string
  default     = null
  sensitive   = true
}

variable "LIGHTDASH_USER_RSA_PUBLIC_KEY" {
  description = "RSA public key for lightdash user. Must be on 1 line without header and trailer."
  type        = string
  default     = null
  sensitive   = true
}

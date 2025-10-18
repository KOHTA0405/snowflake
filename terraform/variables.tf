variable "ENVIRONMENT" {
  description = "Deployment environment"
  type        = string
}

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

variable "SNOWFLAKE_PASSWORD" {
  description = "Snowflake password"
  type        = string
  sensitive   = true
}

variable "SNOWFLAKE_ROLE" {
  description = "Snowflake role"
  type        = string
}

variable "SNOWFLAKE_PRIVATE_KEY_PATH" {
  description = "Path to the Snowflake private key file"
  type        = string
}

variable "SNOWFLAKE_PRIVATE_KEY_PASSPHRASE" {
  description = "Passphrase for the Snowflake private key"
  type        = string
  sensitive   = true
}

variable "SNOWFLAKE_WAREHOUSE" {
  description = "Snowflake warehouse"
  type        = string
}

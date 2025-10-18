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

variable "SNOWFLAKE_PREVIEW_FEATURES" {
  description = "List of preview features to enable for the Snowflake provider."
  type        = list(string)
  default     = []
}

variable "DBT_USER_RSA_PUBLIC_KEY" {
  description = "Primary RSA public key for the dbt service user (PEM body without headers)."
  type        = string
  default     = null
}

variable "DBT_USER_RSA_PUBLIC_KEY_2" {
  description = "Secondary RSA public key for the dbt service user (optional, for rotation)."
  type        = string
  default     = null
}

variable "DBT_PARENT_ROLES" {
  description = "Roles that should inherit the dbt execution role."
  type        = list(string)
  default     = []
}

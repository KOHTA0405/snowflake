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

variable "DLT_USER_RSA_PUBLIC_KEY" {
  description = "RSA public key for dlt_user. Must be on 1 line without header and trailer."
  type        = string
  default     = null
  sensitive   = true
}

variable "DLT_SNOWFLAKE_PRIVATE_KEY" {
  description = "Private key content (PEM) stored as a Snowflake secret for dlt to authenticate to Snowflake."
  type        = string
  sensitive   = true
  default     = null
}

variable "DLT_S3_STAGE_HOST" {
  description = "S3 hostname for Snowflake internal stage. Account/region-specific (e.g. sfc-jp-ds1-24-customer-stage.s3.amazonaws.com). Confirm from error logs on first pipeline run."
  type        = string
  default     = null
}

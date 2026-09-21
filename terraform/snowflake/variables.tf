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

# Keep these declarations while dlt is disabled so existing terraform.tfvars
# values do not produce undeclared-variable warnings during plan.
# tflint-ignore: terraform_unused_declarations
variable "DLT_USER_RSA_PUBLIC_KEY" {
  description = "RSA public key for dlt_user. Must be on 1 line without header and trailer."
  type        = string
  default     = null
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "DLT_SNOWFLAKE_PRIVATE_KEY" {
  description = "Private key content (PEM) stored as a Snowflake secret for dlt to authenticate to Snowflake."
  type        = string
  sensitive   = true
  default     = null
}

# tflint-ignore: terraform_unused_declarations
variable "DLT_S3_STAGE_HOST" {
  description = "S3 hostname for Snowflake internal stage. Account/region-specific (e.g. sfc-jp-ds1-24-customer-stage.s3.amazonaws.com). Confirm from error logs on first pipeline run."
  type        = string
  default     = null
}
variable "iceberg_storage" {
  description = "Iceberg S3 storage details from terraform/aws outputs, keyed by Terraform workspace. Omit until AWS bootstrap is ready."
  type = map(object({
    bucket      = string
    role_arn    = string
    external_id = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for env, storage in var.iceberg_storage :
      contains(["dev", "prd"], env) &&
      can(regex("^[a-z0-9][a-z0-9.-]+$", storage.bucket)) &&
      can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", storage.role_arn)) &&
      length(storage.external_id) > 0
    ])
    error_message = "iceberg_storage must contain dev/prd keys with an S3 bucket, AWS IAM role ARN, and external ID."
  }
}

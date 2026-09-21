variable "snowflake_iceberg_iam_user_arn" {
  description = "STORAGE_AWS_IAM_USER_ARN from DESC EXTERNAL VOLUME. Null during initial bootstrap only."
  type        = string
  default     = null

  validation {
    condition = (
      var.snowflake_iceberg_iam_user_arn == null ||
      can(regex("^arn:aws:iam::[0-9]{12}:user/.+$", var.snowflake_iceberg_iam_user_arn))
    )
    error_message = "Set an AWS IAM user ARN returned by DESC EXTERNAL VOLUME."
  }
}

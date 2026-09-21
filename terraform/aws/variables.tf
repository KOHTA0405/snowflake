variable "snowflake_iceberg_iam_user_arn" {
  description = "STORAGE_AWS_IAM_USER_ARN from DESC EXTERNAL VOLUME. Use null only during initial bootstrap."
  type        = string
  default     = "arn:aws:iam::687622360952:user/hls72000-s"

  validation {
    condition = (
      var.snowflake_iceberg_iam_user_arn == null ||
      can(regex("^arn:aws:iam::[0-9]{12}:user/.+$", var.snowflake_iceberg_iam_user_arn))
    )
    error_message = "Set an AWS IAM user ARN returned by DESC EXTERNAL VOLUME."
  }
}

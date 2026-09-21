# S3 (dbt artifacts)
output "dbt_artifacts_bucket_name" {
  description = "S3 bucket name for dbt artifacts (manifest state + node cache)"
  value       = aws_s3_bucket.dbt_artifacts.bucket
}

output "dbt_artifacts_bucket_arn" {
  description = "S3 bucket ARN for dbt artifacts"
  value       = aws_s3_bucket.dbt_artifacts.arn
}

# IAM (dbt artifacts access, by purpose)
output "dbt_artifacts_iam_user_names" {
  description = "IAM user names in the selected workspace"
  value       = { for k, v in aws_iam_user.dbt_artifacts : k => v.name }
}

output "dbt_artifacts_iam_access_key_ids" {
  description = "IAM access key IDs in the selected workspace"
  value       = { for k, v in aws_iam_access_key.dbt_artifacts : k => v.id }
}

output "dbt_artifacts_iam_secret_access_keys" {
  description = "IAM secret access keys in the selected workspace. Retrieve with `terraform output -json dbt_artifacts_iam_secret_access_keys`; do not print in CI logs."
  value       = { for k, v in aws_iam_access_key.dbt_artifacts : k => v.secret }
  sensitive   = true
}

output "dbt_artifacts_ci_role_arn" {
  description = "IAM role ARN for CI in the selected workspace, or null when CI is not configured"
  value       = try(one(values(aws_iam_role.dbt_artifacts_ci)).arn, null)
}

output "dbt_artifacts_prefect_prd_role_arn" {
  description = "IAM role ARN for the Prefect Cloud prd managed work pool, or null outside prd"
  value       = try(one(values(aws_iam_role.dbt_artifacts_prefect_prd)).arn, null)
}

output "iceberg_bucket_name" {
  description = "S3 bucket name for Iceberg tables in the selected workspace"
  value       = aws_s3_bucket.iceberg.bucket
}

output "iceberg_role_arn" {
  description = "AWS IAM role ARN for the selected workspace's external volume"
  value       = aws_iam_role.iceberg.arn
}

output "iceberg_external_id" {
  description = "Stable external ID for the selected workspace's external volume"
  value       = local.iceberg_external_id
}

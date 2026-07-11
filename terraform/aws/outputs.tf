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
  description = "IAM user names by purpose (prod/dev)"
  value       = { for k, v in aws_iam_user.dbt_artifacts : k => v.name }
}

output "dbt_artifacts_iam_access_key_ids" {
  description = "IAM access key IDs by purpose (prod/dev)"
  value       = { for k, v in aws_iam_access_key.dbt_artifacts : k => v.id }
}

output "dbt_artifacts_iam_secret_access_keys" {
  description = "IAM secret access keys by purpose (prod/dev). Retrieve with `terraform output -json dbt_artifacts_iam_secret_access_keys` and store in Prefect Secret Blocks; do not print in CI logs."
  value       = { for k, v in aws_iam_access_key.dbt_artifacts : k => v.secret }
  sensitive   = true
}

output "dbt_artifacts_ci_role_arn" {
  description = "IAM role ARN for CI (GitHub Actions, dbt_snowflake repo) to assume via OIDC for prod/manifest/* read access"
  value       = aws_iam_role.dbt_artifacts_ci.arn
}

output "dbt_artifacts_prefect_prd_role_arn" {
  description = "IAM role ARN for Prefect Cloud managed work pool (prod) to assume via OIDC workload identity federation"
  value       = aws_iam_role.dbt_artifacts_prefect_prd.arn
}

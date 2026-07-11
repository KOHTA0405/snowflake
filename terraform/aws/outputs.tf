# S3 (dbt artifacts)
output "dbt_artifacts_bucket_name" {
  description = "S3 bucket name for dbt artifacts (manifest state + node cache)"
  value       = aws_s3_bucket.dbt_artifacts.bucket
}

output "dbt_artifacts_bucket_arn" {
  description = "S3 bucket ARN for dbt artifacts"
  value       = aws_s3_bucket.dbt_artifacts.arn
}

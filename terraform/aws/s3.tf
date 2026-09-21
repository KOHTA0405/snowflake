# ============================================================
# dbt成果物永続化用S3バケット (cf. docs/dbt-artifacts-s3-bucket.md)
# ============================================================

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "dbt_artifacts" {
  bucket = local.dbt_artifacts.bucket_name
  tags   = local.dbt_artifacts.tags

  lifecycle {
    precondition {
      condition     = local.is_dev || local.is_prd
      error_message = "Select the dev or prd Terraform workspace before planning or applying dbt artifact resources."
    }
  }
}

resource "aws_s3_bucket_public_access_block" "dbt_artifacts" {
  bucket = aws_s3_bucket.dbt_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dbt_artifacts" {
  bucket = aws_s3_bucket.dbt_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "dbt_artifacts" {
  bucket = aws_s3_bucket.dbt_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# */cache/* 配下のみ一定期間で自動削除する。manifest/* は常に上書きされる単一ファイルなので
# バージョニングの世代管理のみで対応し、ライフサイクルルールは設定しない。
resource "aws_s3_bucket_lifecycle_configuration" "dbt_artifacts" {
  bucket = aws_s3_bucket.dbt_artifacts.id

  dynamic "rule" {
    for_each = local.dbt_artifacts.cache_prefixes
    content {
      id     = "expire-${replace(rule.value, "/", "-")}"
      status = "Enabled"

      filter {
        prefix = rule.value
      }

      expiration {
        days = local.dbt_artifacts.cache_expiration_days
      }

      noncurrent_version_expiration {
        noncurrent_days = local.dbt_artifacts.cache_expiration_days
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.dbt_artifacts]
}

# ============================================================
# Snowflake-managed Iceberg tables 用 S3 バケット
# ============================================================

resource "aws_s3_bucket" "iceberg" {
  bucket = "kohta-snowflake-iceberg-${local.environment}"
  tags   = local.iceberg_tags

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = contains(["dev", "prd"], local.environment)
      error_message = "Select the dev or prd Terraform workspace before planning or applying Iceberg resources."
    }
  }
}

resource "aws_s3_bucket_public_access_block" "iceberg" {
  bucket                  = aws_s3_bucket.iceberg.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "iceberg" {
  bucket = aws_s3_bucket.iceberg.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "iceberg" {
  bucket = aws_s3_bucket.iceberg.id
  versioning_configuration {
    status = "Enabled"
  }
}

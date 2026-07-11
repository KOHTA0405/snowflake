locals {
  dbt_artifacts = {
    bucket_name = "kohta-dbt-snowflake-artifacts"

    # ノード単位キャッシュのprefix。オブジェクトはノード内容のハッシュ由来で増え続けるため、
    # 一定期間で自動削除する(cf. docs/dbt-artifacts-s3-bucket.md)
    cache_prefixes        = ["prod/cache/", "dev/cache/"]
    cache_expiration_days = 30

    tags = {
      Project   = "dbt_snowflake"
      ManagedBy = "terraform"
    }
  }
}

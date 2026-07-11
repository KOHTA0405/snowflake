locals {
  # 用途ごとのIAM User。prefix配下のみGet/Putを許可する(cf. docs/dbt-artifacts-s3-bucket.md)
  dbt_artifacts_iam = {
    prod = {
      user_name = "dbt-snowflake-artifacts-prod"
      prefix    = "prod"
      comment   = "prod Prefect flow: manifest write + node cache read/write"
    }
    dev = {
      user_name = "dbt-snowflake-artifacts-dev"
      prefix    = "dev"
      comment   = "local/dev execution: node cache read/write"
    }
  }
}

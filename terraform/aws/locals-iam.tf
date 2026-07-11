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

  # CI(GitHub Actions, dbt_snowflakeリポジトリ)用。prod/manifest/*のみGet専用。
  # 長期アクセスキーを持たないOIDC + IAM Role方式(cf. docs/dbt-artifacts-iam.md)
  dbt_artifacts_ci = {
    role_name   = "dbt-snowflake-artifacts-ci"
    github_repo = "KOHTA0405/dbt_snowflake"
    prefix      = "prod/manifest"
    comment     = "CI GitHub Actions dbt_snowflake repo: prod-manifest read-only"
  }
}

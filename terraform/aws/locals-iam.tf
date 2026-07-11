locals {
  # 用途ごとのIAM User。prefix配下のみGet/Putを許可する(cf. docs/dbt-artifacts-s3-bucket.md)
  # prodはOIDC(dbt_artifacts_prefect_prd)に移行済みのため削除。devはローカル実行用に維持
  # (cf. docs/prefect-aws-workload-identity.md)
  dbt_artifacts_iam = {
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

  # prod用Prefect managed work pool向け。IAM Userの長期アクセスキーの代わりに
  # AWS workload identity federation(OIDC)で一時クレデンシャルを使う
  # (cf. docs/prefect-aws-workload-identity.md)
  dbt_artifacts_prefect_prd = {
    role_name          = "dbt-snowflake-artifacts-prefect-prd"
    prefect_account_id = "18525c14-7a2a-47a4-a1ed-27fe1fbcce22"
    prefix             = "prod"
    comment            = "prod Prefect managed flow: manifest write + node cache read/write via OIDC"
  }
}

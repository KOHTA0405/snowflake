locals {
  is_dev = local.environment == "dev"
  is_prd = local.environment == "prd"

  iceberg_external_id = uuidv5(
    "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
    "${data.aws_caller_identity.current.account_id}:snowflake-iceberg:${local.environment}"
  )

  # ローカル dev 実行だけは、OIDC を利用できないため IAM User を使う。
  dbt_artifacts_iam = local.is_dev ? {
    (local.environment) = {
      user_name = "dbt-snowflake-artifacts-dev"
      prefix    = ""
      comment   = "local/dev execution: node cache read/write"
    }
  } : {}

  # CI は prd の manifest のみを読む。
  # 長期アクセスキーを持たないOIDC + IAM Role方式(cf. docs/dbt-artifacts-iam.md)
  dbt_artifacts_ci = local.is_prd ? {
    (local.environment) = {
      role_name   = "dbt-snowflake-artifacts-ci-prd"
      github_repo = "KOHTA0405/dbt_snowflake"
      prefix      = "manifest"
      comment     = "CI GitHub Actions dbt_snowflake repo: prd manifest read-only"
    }
  } : {}

  # prd 用 Prefect managed work pool 向け。IAM Userの長期アクセスキーの代わりに
  # AWS workload identity federation(OIDC)で一時クレデンシャルを使う
  # (cf. docs/prefect-aws-workload-identity.md)
  dbt_artifacts_prefect = local.is_prd ? {
    (local.environment) = {
      role_name          = "dbt-snowflake-artifacts-prefect-prd"
      prefect_account_id = "18525c14-7a2a-47a4-a1ed-27fe1fbcce22"
      prefix             = ""
      comment            = "prd Prefect managed flow: manifest write + node cache read/write via OIDC"
    }
  } : {}
}

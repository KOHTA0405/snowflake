# ============================================================
# dbt成果物バケット用IAM (cf. docs/dbt-artifacts-s3-bucket.md)
# 用途ごとにIAM Userを分離し、prefix配下のみGet/Putを許可する
# ============================================================

data "aws_iam_policy_document" "dbt_artifacts_access" {
  for_each = local.dbt_artifacts_iam

  statement {
    sid       = "ListBucketPrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.dbt_artifacts.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${each.value.prefix}/*"]
    }
  }

  statement {
    sid       = "ReadWriteObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.dbt_artifacts.arn}/${each.value.prefix}/*"]
  }
}

resource "aws_iam_user" "dbt_artifacts" {
  for_each = local.dbt_artifacts_iam
  name     = each.value.user_name
  tags     = merge(local.dbt_artifacts.tags, { Comment = each.value.comment })
}

resource "aws_iam_user_policy" "dbt_artifacts" {
  for_each = local.dbt_artifacts_iam
  name     = "${each.value.user_name}-s3-access"
  user     = aws_iam_user.dbt_artifacts[each.key].name
  policy   = data.aws_iam_policy_document.dbt_artifacts_access[each.key].json
}

resource "aws_iam_access_key" "dbt_artifacts" {
  for_each = local.dbt_artifacts_iam
  user     = aws_iam_user.dbt_artifacts[each.key].name
}

# ============================================================
# CI(GitHub Actions, dbt_snowflakeリポジトリ)用
# 長期アクセスキーを持たず、OIDCフェデレーション経由でRoleをAssumeする
# ============================================================

# GitHub ActionsのOIDC IDプロバイダーはこのAWSアカウントに既に存在する
# (terraform-pr.ymlのAWS認証で使用中、Terraform管理外で作成済み)ためdataで参照する
data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "dbt_artifacts_ci_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.dbt_artifacts_ci.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "dbt_artifacts_ci" {
  name               = local.dbt_artifacts_ci.role_name
  assume_role_policy = data.aws_iam_policy_document.dbt_artifacts_ci_trust.json
  tags               = merge(local.dbt_artifacts.tags, { Comment = local.dbt_artifacts_ci.comment })
}

data "aws_iam_policy_document" "dbt_artifacts_ci_access" {
  statement {
    sid       = "ListBucketManifestPrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.dbt_artifacts.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${local.dbt_artifacts_ci.prefix}/*"]
    }
  }

  statement {
    sid     = "ReadManifestObjects"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    # prefix配下の全オブジェクトが対象のため末尾ワイルドカードは構造上必須。
    # bucket/actionはprod/manifest/*・s3:GetObjectのみに限定済み。
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["${aws_s3_bucket.dbt_artifacts.arn}/${local.dbt_artifacts_ci.prefix}/*"]
  }
}

resource "aws_iam_role_policy" "dbt_artifacts_ci" {
  name   = "${local.dbt_artifacts_ci.role_name}-s3-read"
  role   = aws_iam_role.dbt_artifacts_ci.name
  policy = data.aws_iam_policy_document.dbt_artifacts_ci_access.json
}

# ============================================================
# Prefect Cloud managed work pool(prod)用
# AWS workload identity federationでIAM Userの長期アクセスキーを
# 廃止し、一時クレデンシャルに切り替える (cf. docs/prefect-aws-workload-identity.md)
# 旧IAM User(dbt-snowflake-artifacts-prod)は動作確認が取れるまで並行稼働のため残す
# ============================================================

resource "aws_iam_openid_connect_provider" "prefect_cloud" {
  url            = "https://api.prefect.cloud/oidc-provider"
  client_id_list = ["prefect-cloud"]
}

data "aws_iam_policy_document" "dbt_artifacts_prefect_prd_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.prefect_cloud.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "api.prefect.cloud/oidc-provider:aud"
      values   = ["prefect-cloud"]
    }

    condition {
      test     = "StringEquals"
      variable = "api.prefect.cloud/oidc-provider:sub"
      values   = ["prefect:account:${local.dbt_artifacts_prefect_prd.prefect_account_id}"]
    }
  }
}

resource "aws_iam_role" "dbt_artifacts_prefect_prd" {
  name               = local.dbt_artifacts_prefect_prd.role_name
  assume_role_policy = data.aws_iam_policy_document.dbt_artifacts_prefect_prd_trust.json
  tags               = merge(local.dbt_artifacts.tags, { Comment = local.dbt_artifacts_prefect_prd.comment })
}

resource "aws_iam_role_policy" "dbt_artifacts_prefect_prd" {
  name   = "${local.dbt_artifacts_prefect_prd.role_name}-s3-access"
  role   = aws_iam_role.dbt_artifacts_prefect_prd.name
  policy = data.aws_iam_policy_document.dbt_artifacts_access["prod"].json
}

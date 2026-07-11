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

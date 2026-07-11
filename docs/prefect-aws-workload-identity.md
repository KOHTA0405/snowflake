# Prefect Cloud向けAWS認証をOIDC(workload identity federation)に移行する

[dbt-artifacts-iam.md](./dbt-artifacts-iam.md)で「ベストプラクティスから外れている点」として指摘した、prod用IAM Userの長期アクセスキーを廃止するための変更メモ。

**実装・動作確認・完了**。Terraform(`terraform/aws/`)・Prefect Cloud側(`dbt_snowflake`リポジトリの`prefect.yaml`・`aws-credentials-prd` Block)ともに変更済みで、prd targetのflow runを2回(旧IAM User削除の前後で1回ずつ)実行して正常完了を確認した。旧IAM User(`dbt-snowflake-artifacts-prod`)・アクセスキー・インラインポリシーは`locals-iam.tf`の`dbt_artifacts_iam`から`prod`エントリを削除し、`terraform apply`で削除済み。`aws_iam_role_policy.dbt_artifacts_prefect_prd`は旧`dbt_artifacts_access["prod"]`ではなく専用の`dbt_artifacts_prefect_prd_access`ポリシードキュメントを参照するよう分離した(削除したlocalsへの依存を切るため)。

## 前提が変わった点

`dbt-artifacts-iam.md`では以下を「未確認の前提条件」として据え置きの理由にしていた。

> Prefectの`AwsCredentials`/`S3Bucket`ブロック(prefect-aws)がrole assumeのフローに対応しているかどうか

調べたところ、Prefect Managed work pool自体に「AWS workload identity federation」という機能があり、**flowコード側で何もしなくても**Prefect Cloudが自動的にSTSの`AssumeRoleWithWebIdentity`を呼び、一時クレデンシャルを実行環境の環境変数(`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN`)として注入することが分かった。`AwsCredentials`ブロックの`aws_access_key_id`/`aws_secret_access_key`はそもそもOptionalで、未設定ならboto3の標準認証チェーン(環境変数を優先的に見る)にフォールバックする実装なので、既存の`S3Bucket`/`AwsCredentials`ブロックの構造を変えずに対応できる見込み。

つまり「据え置きの前提条件」は解消された。GitHub Actions用に実装済みの`dbt-snowflake-artifacts-ci`(OIDC + Role、`terraform/aws/iam.tf`)と同型の構成を、prod用のPrefect flowにも適用できる。

## 対象範囲

**prod用(`dbt-snowflake-artifacts-prod`)のみ**。dev用(`dbt-snowflake-artifacts-dev`)は対象外。

理由: dev targetは現状Prefect Cloudのmanaged実行ではなくローカル実行が前提([dbt_snowflakeリポジトリ]の`flows/dbt_build_flow.py`もdevではS3アップロード/キャッシュを使わない実装になっている)。workload identity federationはPrefect Managed work poolの機能なので、ローカル実行には効かない。dev用の長期アクセスキーは今回は現状維持。

## Terraform側の変更(`terraform/aws/`、実装済み)

### 1. Prefect CloudのOIDCプロバイダを新規作成

GitHub Actionsの場合は`data "aws_iam_openid_connect_provider" "github_actions"`(このAWSアカウントに既存のものをTerraform管理外で参照)だったが、Prefect Cloud用は存在しないため`resource`で新規作成した。

```hcl
# iam.tf
resource "aws_iam_openid_connect_provider" "prefect_cloud" {
  url            = "https://api.prefect.cloud/oidc-provider"
  client_id_list = ["prefect-cloud"]
}
```

`client_id_list`(audience)は`prefect-cloud`、`thumbprint_list`は省略可(AWSプロバイダがTLS証明書から自動取得)であることを[Prefect公式ドキュメント](https://docs.prefect.io/v3/how-to-guides/deployment_infra/managed-aws-federated-identity)で確認済み。

### 2. IAM Roleを新規作成(既存のprod用IAM Userの代替)

`dbt_artifacts_ci`(CI用)と同じパターンを踏襲。信頼ポリシーは`aud`(audience)と`sub`(Prefect CloudのアカウントID)の両方を条件にした(CI用Roleの`aud`/`sub`条件と同じ構成)。

```hcl
# locals-iam.tf
locals {
  dbt_artifacts_prefect_prd = {
    role_name           = "dbt-snowflake-artifacts-prefect-prd"
    prefect_account_id = "18525c14-7a2a-47a4-a1ed-27fe1fbcce22"
    prefix              = "prod"
    comment             = "prod Prefect managed flow: manifest write + node cache read/write via OIDC"
  }
}
```

```hcl
# iam.tf
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
```

`prefect_account_id`はPrefect CloudのアカウントID(UUID)で、非公開リポジトリでも伏せる必要のある秘密情報ではない(信頼関係の安全性はPrefect Cloudが署名した実際のOIDCトークンの検証に依存しており、アカウントIDを知っているだけでは`AssumeRoleWithWebIdentity`を偽装できないため)。CI用Roleの`github_repo`と同様、直接localsに書いている。

**注意**: `sub`をアカウントID単位でしか絞れない(Prefect Cloud側がワークスペース/ワークプール単位のより細かいsub claimを出しているかは未確認)。この場合、同じPrefect Cloudアカウント内の他のwork pool/flowにもこのRoleをAssumeできる余地が生まれる。現状はこのアカウントで動くPrefectのflowが`dbt-build`のみなので実害は小さいが、将来flowが増えたら要再検討。

### 3. 権限ポリシーは既存の`dbt_artifacts_access["prod"]`を流用

現行の`aws_iam_user_policy.dbt_artifacts["prod"]`と同じ内容(`prod/*`へのList/Get/Put)を、IAM Userではなく新しいIAM Roleにアタッチした。

```hcl
resource "aws_iam_role_policy" "dbt_artifacts_prefect_prd" {
  name   = "${local.dbt_artifacts_prefect_prd.role_name}-s3-access"
  role   = aws_iam_role.dbt_artifacts_prefect_prd.name
  policy = data.aws_iam_policy_document.dbt_artifacts_access["prod"].json
}
```

`data.aws_iam_policy_document.dbt_artifacts_access`は`for_each = local.dbt_artifacts_iam`で定義済みなので、`prod`キーのポリシーをそのまま参照できる。

### 4. outputsに新しいRoleのARNを追加

```hcl
# outputs.tf
output "dbt_artifacts_prefect_prd_role_arn" {
  description = "IAM role ARN for Prefect Cloud managed work pool (prod) to assume via OIDC workload identity federation"
  value       = aws_iam_role.dbt_artifacts_prefect_prd.arn
}
```

apply済み。Role ARN: `arn:aws:iam::730335183162:role/dbt-snowflake-artifacts-prefect-prd`

なお`aws_iam_role`の`tags`はAWSタグ値の文字種制約(`()`, `,`, `*`などは不可)に引っかかりやすい(CI用Roleと同様、今回も`comment`に`(OIDC)`と書いて初回applyでエラーになったため`via OIDC`に修正した)。

### 5. 移行完了後: 旧IAM User/アクセスキーを削除(実施済み)

`locals-iam.tf`の`dbt_artifacts_iam`マップから`prod`エントリを削除(`dev`は残置)。これにより`aws_iam_user.dbt_artifacts["prod"]`・`aws_iam_access_key.dbt_artifacts["prod"]`・対応するインラインポリシーが`for_each`から外れ、`terraform apply`で削除された(`Plan: 0 to add, 0 to change, 3 to destroy`)。

これに伴い、`aws_iam_role_policy.dbt_artifacts_prefect_prd`が参照していた`data.aws_iam_policy_document.dbt_artifacts_access["prod"]`(削除される`dbt_artifacts_iam["prod"]`に依存)を、独立した`data.aws_iam_policy_document.dbt_artifacts_prefect_prd_access`に切り出した。内容(prod/*へのList/Get/Put)は変更なし。

## Prefect Cloud側で実施した作業

このリポジトリの管轄外(`dbt_snowflake`リポジトリ側)だが、実施内容を記録しておく。

1. Prefect CloudのアカウントID確認 → `prefect_account_id`に設定(実施済み)
2. `prefect.yaml`の`job_variables`に`federated_identity`(Role ARN + `ap-northeast-1`)を追加し、`prefect deploy`で反映(Work Poolの設定画面ではなく、デプロイ単位でjob_variablesとして指定する方式を採用)
3. `aws-credentials-prd` Secret Blockのアクセスキーを空にして再保存(boto3の環境変数フォールバックに委ねる)。`s3-bucket-prd`/`s3-bucket-prd-cache` Blockは`aws-credentials-prd`をBlock参照(値のコピーではない)で持っているため、この1箇所の更新だけで両方に反映される
4. `prefect deployment run 'dbt-build/dbt-build'`で動作確認(旧IAM User削除の前後で2回実行、いずれも`Completed`)

詳細は[dbt_snowflakeリポジトリ]側のPrefect関連docsを参照。

## ロールバック方針(実施済みの記録)

新Role切り替え後、旧IAM Userは動作確認が取れるまで並行稼働させた上で削除する方針で進めた。実際には切り替え後の1回目の動作確認が成功した時点で旧IAM Userを削除している。もし今後同様の切り替えが必要になった場合、旧方式へ戻すには以下が必要(現在は旧IAM Userを削除済みのため、戻すには再作成が必要):

- Terraform側: `locals-iam.tf`の`dbt_artifacts_iam`に`prod`エントリを戻して`terraform apply`(IAM User・アクセスキーを再作成)
- Prefect Cloud側: `aws-credentials-prd` Blockに再発行したアクセスキーを設定し直す

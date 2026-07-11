# Prefect Cloud向けAWS認証をOIDC(workload identity federation)に移行する

[dbt-artifacts-iam.md](./dbt-artifacts-iam.md)で「ベストプラクティスから外れている点」として指摘した、prod用IAM Userの長期アクセスキーを廃止するための変更メモ。

**Terraform側(`terraform/aws/`)は実装・apply済み**。Prefect Cloud側の設定・動作確認はまだ(下記「Prefect Cloud側で必要な作業」を参照)。旧IAM User(`dbt-snowflake-artifacts-prod`)は動作確認が取れるまで並行稼働のため残している。

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

### 5. 移行完了後: 旧IAM User/アクセスキーを削除(未実施)

動作確認が取れたら、`locals-iam.tf`の`dbt_artifacts_iam`マップから`prod`エントリを削除する(`dev`は残す)。これにより`aws_iam_user.dbt_artifacts["prod"]`・`aws_iam_access_key.dbt_artifacts["prod"]`・対応するインラインポリシーが`for_each`から外れ、`terraform apply`で削除される。

## Prefect Cloud側で必要な作業(このリポジトリの管轄外・参考まで)

1. Prefect CloudのアカウントID確認(UIまたは`prefect cloud workspace ls`)→ 上記`prefect_account_id`に設定
2. `default-work-pool`の設定画面で「Federated Identity」にRoleのARN + リージョンを入力
3. `aws-credentials-prd` Secret Blockを空認証情報で再保存(またはブロックごと削除して環境変数フォールバックに委ねる)
4. `prefect deployment run 'dbt-build/dbt-build'`で動作確認

詳細は[dbt_snowflakeリポジトリ]側のPrefect関連docsを参照。

## ロールバック方針

新Roleの動作確認が取れるまでは、旧IAM User(`dbt-snowflake-artifacts-prod`)とアクセスキーは削除せず並行稼働させる。Prefect Cloud側のBlock設定を新方式に切り替えて問題が出た場合、`aws-credentials-prd` Blockを元の値に戻すだけで即座に旧方式へ戻せる状態を維持する。

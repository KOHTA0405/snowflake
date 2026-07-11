# dbt成果物バケット用IAMのメモ(ベストプラクティスからの逸脱について)

## 現状の実装

`terraform/aws/iam.tf`で、prod/dev用にそれぞれ専用のIAM Userを作成し、対応するprefix
(`prod/*` / `dev/*`)のみへの`s3:ListBucket`(prefix条件付き)・`s3:GetObject`・
`s3:PutObject`を許可する**インラインポリシーを直接アタッチ**している。

- `dbt-snowflake-artifacts-prod` — `prod/*`のみ
- `dbt-snowflake-artifacts-dev` — `dev/*`のみ
- アクセスキー(`aws_iam_access_key`)を発行し、Prefect Secret Blockに手動登録する想定

## ベストプラクティスではない点

AWSのIAM best practicesと比べると、主に2点で外れている。

1. **長期間有効な認証情報(IAM Userのアクセスキー)を使っている**
   AWSの推奨は「ロールをAssumeして得る一時的な認証情報を優先し、IAM Userの長期
   アクセスキーは極力使わない」。今回はUserのアクセスキーをPrefect Secret Blockに
   保存する構成なので、これに反している。優先度としてはこちらが本命の指摘。
2. **ポリシーをグループ経由でなくUserに直接アタッチしている**
   AWSの推奨は「ポリシーはグループに付与し、Userをグループに所属させる」。
   こちらは主に運用のしやすさのための推奨で、今回のように1ユーザー1用途の
   専用サービスアカウント(他に同じ権限を必要とするUserが増える想定がない)
   では実務上の影響は小さい。

## ベストプラクティスに即した方法

- S3への実際の権限は**IAM Role**側に持たせる(Userに直接付けているインライン
  ポリシーをRoleに移す)
- Roleを引き受ける方式は2通り考えられる
  1. `sts:AssumeRole`のみを持つIAM Userを別途用意し、一時的な認証情報を都度取得する
  2. OIDCフェデレーションでIAM Userを介さずに直接Roleを引き受ける(実行環境がOIDC
     トークンを発行できる場合のみ可能)
- prodは2の方式(OIDC)が実際に使えることが分かったため、下記の通り移行済み
- devはローカル実行のためOIDCトークンを発行できず、1の方式も「最初に持つ、
  長期間有効な認証情報」がどこかに必要になる点でUser直付けと大差ないため、
  User直付けのまま据え置いている

## CI用IAMは実装済み(Role方式)

CI(GitHub Actions)側は事情が異なり、OIDCフェデレーションが使えるため
IAM User無しでRoleだけで完結できる。既存の`terraform-pr.yml`が使っている
`AWS_IAM_ROLE_ARN`はまさにこのパターンで、今回追加した
`dbt-snowflake-artifacts-ci`(`terraform/aws/iam.tf`)も同様にRoleのみで実装した
(長期アクセスキー無し)。詳細は
[dbt-artifacts-s3-bucket.md](./dbt-artifacts-s3-bucket.md)の「CI用IAM(実装済み)」を参照。

## prod用はRole方式への移行を実装済み(Prefect Cloud側の切り替えは未実施)

Prefect Managed work poolにAWS workload identity federationの機能があり、flow
コード側の変更無しにPrefect Cloudが自動的にSTSの`AssumeRoleWithWebIdentity`を
呼んで一時クレデンシャルを注入できることが分かった。Terraform側(`terraform/aws/`)
はCI用Roleと同型の構成(OIDCプロバイダー + IAM Role)をprod用に実装・apply済み。
詳細は[prefect-aws-workload-identity.md](./prefect-aws-workload-identity.md)を参照。

Prefect Cloud側の設定切り替え・動作確認が済むまでは、旧IAM User
(`dbt-snowflake-artifacts-prod`)を並行稼働のため残している。動作確認後に
削除する予定(同docsの「移行完了後」の項を参照)。

dev用はローカル実行が前提でworkload identity federationの対象外
(Prefect Managed work poolの機能のため)。以下は据え置いた理由。

Prefect CloudのmanagedexecutionはAWSネイティブなコンピュート環境ではなく、
instance profileやexecution roleのような自動的なRole紐付けの仕組みが無い。
そのため「最初に持つ、長期間有効な認証情報」がどこかに必要になり、
dev用は今回もUser直付けを選択した。リスクはprefixごとの最小権限スコープ
(`dev/*`だけ)で抑えている。

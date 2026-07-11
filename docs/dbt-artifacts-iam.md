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

## ベストプラクティスに即した方法(将来やるなら)

- S3への実際の権限は**IAM Role**側に持たせる(現在Userに直接付けているインライン
  ポリシーをRoleに移す)
- そのRoleを引き受けるための最小権限(`sts:AssumeRole`のみ)を持つIAM Userを別途
  用意し、実際のS3操作は一時的な(有効期限付きの)認証情報で行う
- **前提条件(未確認)**: Prefectの`AwsCredentials`/`S3Bucket`ブロック(prefect-aws)が
  role assumeのフローに対応しているかどうか。対応していなければ、flowコード内で
  手動で`sts:AssumeRole`を呼んでboto3セッションを組み立てる実装が別途必要になり、
  素のUser直付けよりも複雑さが増す
- prod/devについては上記の前提条件が未確認のため、現時点でもUser直付けのまま
  据え置いている

## CI用IAMは実装済み(Role方式)

CI(GitHub Actions)側は事情が異なり、OIDCフェデレーションが使えるため
IAM User無しでRoleだけで完結できる。既存の`terraform-pr.yml`が使っている
`AWS_IAM_ROLE_ARN`はまさにこのパターンで、今回追加した
`dbt-snowflake-artifacts-ci`(`terraform/aws/iam.tf`)も同様にRoleのみで実装した
(長期アクセスキー無し)。詳細は
[dbt-artifacts-s3-bucket.md](./dbt-artifacts-s3-bucket.md)の「CI用IAM(実装済み)」を参照。

## 現状のまま進めた理由

Prefect CloudのmanagedexecutionはAWSネイティブなコンピュート環境ではなく、
instance profileやexecution roleのような自動的なRole紐付けの仕組みが無い。
そのため「最初に持つ、長期間有効な認証情報」がどこかに必要になり、
今回はUser直付けを選択した。リスクはprefixごとの最小権限スコープ
(`prod/*`だけ、`dev/*`だけ)で抑えている。

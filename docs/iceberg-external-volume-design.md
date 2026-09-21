# Iceberg 用 S3 と external volume 設計

## 目的と前提

- dbt が作成する一部の Gold モデルを Snowflake 管理の Iceberg テーブルにし、データと Iceberg メタデータを自社 AWS アカウントの S3 に保存する。
- ローカルの DuckDB は Snowflake Horizon Catalog の Iceberg REST API からテーブルを発見し、一時的なストレージ認証情報で読み取る。S3 の長期アクセスキーは配布しない。
- Snowflake アカウントのリージョンは `AWS_AP_NORTHEAST_1`、既存の AWS provider は `ap-northeast-1`。S3 も東京リージョンに作る。
- Snowflake の `DEV` と `PRD` は同じアカウント内の別データベース。Iceberg 用 AWS Terraform と Snowflake Terraform は、それぞれ `dev` / `prd` workspace を使う。AWS 側と Snowflake 側は別 state。
- 2026-09-22 時点の設計。対象 provider は `snowflakedb/snowflake` 2.21 系。

## まず全体像

Iceberg テーブルは Snowflake 上で作成・管理するが、実際のデータとメタデータは AWS の S3 に保存する。その接続のために、AWS 側と Snowflake 側で次を用意する。

| 用意するもの | 何のために必要か |
| --- | --- |
| AWS の Iceberg 用 S3 バケット | テーブルのデータとメタデータを保存する場所。dev と prd で別バケットにする。 |
| AWS の IAM ロール | Snowflake が対応するバケットの `tables/` 配下を読み書きするための権限。 |
| Snowflake の external volume | S3 の保存先と AWS IAM ロールを Snowflake に教える接続設定。dev は `ICEBERG_DEV`、prd は `ICEBERG_PRD`。 |
| dbt 実行ロールへの volume の `USAGE` | dbt がその external volume を使って Iceberg テーブルを作成できるようにする。 |
| `GOLD` スキーマの既定設定 | Iceberg テーブルが使う volume を指定し、他エンジンでも読みやすい `COMPATIBLE` 形式で書き込む。 |

処理の流れは「dbt の対象モデル → Snowflake の Iceberg テーブル → external volume → AWS IAM ロール → S3」。dbt は Iceberg にしたいモデルだけ `materialized='table'` と `table_format='iceberg'` を指定する。`GOLD` スキーマに volume を設定しても、既存の view や通常の table が自動で Iceberg に変わるわけではない。外部ストレージを確実に使うため、モデル側でも対応する `ICEBERG_DEV` / `ICEBERG_PRD` を明示する。

現在構築済みなのは dev の AWS・Snowflake リソースだけ。prd は Terraform に定義済みだが、まだ apply していない。外部 volume の S3 読み書き検証と、dbt モデルの実行もこれから行う。

## 構成

| 環境 | S3 バケット | 保存先 | AWS IAM ロール | Snowflake external volume |
| --- | --- | --- | --- | --- |
| dev | `kohta-snowflake-iceberg-dev` | `s3://kohta-snowflake-iceberg-dev/tables/` | `snowflake-iceberg-dev` | `ICEBERG_DEV` |
| prd | `kohta-snowflake-iceberg-prd` | `s3://kohta-snowflake-iceberg-prd/tables/` | `snowflake-iceberg-prd` | `ICEBERG_PRD` |

バケット名は環境名で分ける。dbt 成果物用バケットも環境ごとに分離する。各環境の volume は、その環境に属する複数の Iceberg テーブルで共有する。テーブルごとの `BASE_LOCATION` は dbt が既定で `_dbt/<schema>/<model>` の形に設定するため、通常はモデル側で変更しない。

## AWS 側

Iceberg 用 S3・IAM と dbt 成果物用 S3・IAM は `terraform/aws` の同じ Terraform ルートで管理する。AWS backend は `workspace_key_prefix = "aws"`、`key = "tfstate"` とし、state は `aws/dev/tfstate` と `aws/prd/tfstate` に置く。Snowflake backend は `snowflake/dev/tfstate` と `snowflake/prd/tfstate` に置く。

backend を利用する IAM principal には、上記の state と `.tflock` オブジェクトに対する必要な S3 権限が要る。既存 backend のポリシーが旧 state key に限定されている場合は、新しい `aws/<workspace>/tfstate` と `snowflake/<workspace>/tfstate` を許可する。

### dbt artifacts AWS ルートの環境分離

`terraform/aws` は `workspace_key_prefix = "aws"` を使い、`dev` と `prd` の state を分ける。`default` workspace は plan/apply の事前条件で拒否する。dbt artifacts のバケットも環境ごとに分け、S3 prefix だけに依存した環境分離をやめる。

| workspace | S3 バケット | IAM |
| --- | --- | --- |
| `dev` | `kohta-dbt-snowflake-artifacts-dev` | ローカル実行用 `dbt-snowflake-artifacts-dev` IAM User。バケット全体の読み書き。 |
| `prd` | `kohta-dbt-snowflake-artifacts-prd` | Prefect Cloud 用 `dbt-snowflake-artifacts-prefect-prd` IAM Role（バケット全体の読み書き）と、CI 用 `dbt-snowflake-artifacts-ci-prd` IAM Role（`manifest/*` の読取のみ）。 |

各バケットには公開ブロック、SSE-S3、バージョニング、および `cache/` だけを対象にした 30 日のライフサイクルを設定する。Prefect Cloud の OIDC provider は AWS アカウント内で URL が一意になるため `prd` workspace だけが管理する。GitHub Actions OIDC provider と backend バケットは Terraform 管理外の既存リソースとして data/ backend で参照する。

旧 `default` state の共有バケットと IAM リソースは 2026-09-22 に削除済み。旧バケットはバージョニングが有効だったため、通常の `destroy` は `BucketNotEmpty` で停止した。残存したバケットに一時的に `force_destroy=true` を適用して全オブジェクトバージョンと delete marker を削除し、再度 `destroy` して完了した。一時設定は Terraform コードから撤去済み。

`terraform/aws` の `dev` workspace は 2026-09-22 に apply 済み。同日、2つの dev バケットをアカウント ID のない名前へ置き換え済み。次は `prd` workspace の plan / apply と、出力された CI Role ARN・Prefect Role ARN・S3 バケット名の dbt/Prefect 側への設定を進める。

各 workspace で次を管理する。`default` での plan・apply は事前条件で失敗させる。

- 専用 S3 バケット。パブリックアクセスを全面ブロックし、SSE-S3 暗号化とバージョニングを有効にする。
- バケットと external volume には Terraform の `prevent_destroy` を設定し、設定値の欠落や意図しない置換による削除を防ぐ。
- 現行データやメタデータを対象とする自動削除ルールは設定しない。保持期間は実データ量と Snowflake のスナップショット運用を確認してから決める。
- 環境専用 IAM ロール。`tables/` 配下に限って `GetObject`、`GetObjectVersion`、`PutObject`、`DeleteObject`、`DeleteObjectVersion` を許可する。バケットに対する `ListBucket` は当該 prefix に限定する。`GetBucketLocation` はバケット ARN に許可する。
- ロール信頼ポリシーは Snowflake アカウントの IAM ユーザー ARN と、その volume 専用の external ID の組み合わせに限定する。dev と prd でロール、external ID、保存先を共有しない。

external ID は AWS アカウント ID と環境名から `uuidv5` で固定生成する。これは認証用の秘密値ではなく、IAM ロールの principal 制限と組み合わせて使う。選択中の workspace の生成値は `terraform output iceberg_external_id` で確認できる。

Snowflake 管理の Iceberg テーブルは書き込みを行うため、volume の `ALLOW_WRITES` は `TRUE` とする。DuckDB 用に AWS IAM ユーザーや固定アクセスキーは作らない。

## Snowflake 側

`terraform/snowflake` で workspace ごとに次を管理する。

- `snowflake_external_volume` を 1 件。`STORAGE_PROVIDER = S3`、`STORAGE_BASE_URL` は上表の `tables/`、`STORAGE_AWS_ROLE_ARN` は対応する IAM ロール、`STORAGE_AWS_EXTERNAL_ID` は環境専用の固定値を指定する。
- volume は SYSADMIN 所有とする。初回のみ `ACCOUNTADMIN` から `SYSADMIN` に `CREATE EXTERNAL VOLUME` アカウント権限を付与する。通常の Terraform 実行で `ACCOUNTADMIN` は使わない。
- dbt 実行ロール `ADMINISTRATOR_DEV` / `ADMINISTRATOR_PRD` に対応する volume の `USAGE` を付与する。Iceberg テーブルの所有ロールは `USAGE` を維持する。
- `GOLD` スキーマに `EXTERNAL_VOLUME = ICEBERG_<ENV>` と `STORAGE_SERIALIZATION_POLICY = COMPATIBLE` を設定する。後者は DuckDB など他エンジンとの互換性を確保するため、最初の Iceberg テーブル作成前に設定する。テーブル作成後に当該テーブルの serialization policy は変更できない。
- Gold 内でも dbt で Iceberg と明示したモデルだけをテーブル化する。既存の view モデルは段階的に切り替える。

Snowflake Terraform は選択中の `dev` / `prd` workspace と AWS caller identity から、対応する Iceberg バケット名、IAM ロール ARN、固定 external ID を自動的に組み立てる。AWS と Snowflake の Terraform 実行には同じ AWS アカウントの認証情報を使う。`default` workspace では volume と Gold の既定値を作成・変更しない。AWS state 全体には dev 用アクセスキーが含まれるため、Snowflake 側から remote state を読み取らない。

DuckDB の参照ロールは Gold のデータベース・スキーマ `USAGE` と対象 Iceberg テーブル `SELECT` に絞る。DuckDB は Horizon Catalog に認証し、credential vending を使う。DuckDB に external volume の `USAGE` や S3 IAM ロールは付与しない。

## 初回接続手順

AWS と Snowflake が別 state のため、初回は段階的に構築する。

1. `terraform/aws` で通常の `terraform init` を実行し、`terraform workspace new dev` または `terraform workspace select dev` で `dev` を選択する。`terraform workspace show` が `dev` であることを確認してから plan・apply する。Snowflake IAM ユーザー ARN がまだ不明な初回構築時は、`snowflake_iceberg_iam_user_arn` の既定値を一時的に `null` にする。この場合、IAM 信頼ポリシーは自 AWS アカウントの root principal と環境専用 external ID に限定される一時状態となる。この時点で Snowflake からのアクセスはできない。
2. 1 回だけ `ACCOUNTADMIN` で `GRANT CREATE EXTERNAL VOLUME ON ACCOUNT TO ROLE SYSADMIN` を実行する。
3. Snowflake Terraform の `dev` workspace で plan を確認し、volume、dbt ロールへの `USAGE`、Gold スキーマの既定値を apply する。バケット名・ロール ARN・external ID は AWS 側と同じ規則から自動設定される。Snowflake 接続用の `TF_VAR_SNOWFLAKE_*` は実行前に読み込む。
4. `DESC EXTERNAL VOLUME ICEBERG_DEV` から `STORAGE_AWS_IAM_USER_ARN` を取得する。Snowflake はアカウント内の S3 external volume に同じ IAM ユーザーを使う。
5. AWS `dev` workspace の `snowflake_iceberg_iam_user_arn` に取得した ARN を設定し、信頼ポリシーを Snowflake IAM ユーザー ARN に変更する。AWS の plan で差分が信頼ポリシーの principal のみであることを確認する。取得済みの ARN は変数の既定値に保存してあり、後続の plan・apply でも維持する。
6. `SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('ICEBERG_DEV')` で認証と書き込みを検証する。
7. `prd` についても AWS workspace の作成・apply、Snowflake workspace の apply、AWS 信頼ポリシー更新・apply、volume 検証を同じ順序で行う。既に取得した Snowflake IAM ユーザー ARN を再利用できる。
8. 対応する Gold モデルを Iceberg テーブルとして作り、Horizon Catalog 経由で DuckDB から読めることを確認する。

初回の信頼ポリシーには、他社アカウントの principal や全 AWS principal のワイルドカードを使わない。external ID を明示することで、volume の再作成時に Snowflake 生成 ID が変わって信頼関係が壊れる事態を避ける。

## 確認項目

- AWS と Snowflake の Terraform `fmt`・`validate`・`plan`。現在、`fmt` と `validate` は成功。`plan` は接続情報を含む実行環境で確認する。
- バケットのリージョン、公開ブロック、暗号化、バージョニング、IAM ポリシーの prefix 制限。
- 各 volume の `SYSTEM$VERIFY_EXTERNAL_VOLUME` 成功。
- dbt が Gold の対象モデルを Snowflake 管理 Iceberg テーブルとして作成できること。
- DuckDB が Horizon Catalog から対象テーブルを読み、dev ロールで prd テーブルを参照できないこと。

## 現在の進捗

- 設計書、AWS ルートの Iceberg 用 S3・IAM、Snowflake の volume・権限・Gold スキーマ既定値を Terraform に追加済み。
- Iceberg 用 AWS リソースを `terraform/aws` に統合済み。AWS と Snowflake の backend は provider / workspace 順の key に整理済み。
- AWS `dev` workspace と Snowflake `dev` workspace は apply 済み。`ICEBERG_DEV` を作成し、AWS Iceberg ロールの信頼先を Snowflake IAM ユーザー ARN に更新済み。volume の接続検証、AWS `prd` / Snowflake `prd` の apply、dbt モデル変更、DuckDB 接続確認は未実施。

## 参照資料

- [HashiCorp: S3 backend と workspace の state 配置](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Snowflake: external volume の構成](https://docs.snowflake.com/en/user-guide/tables-iceberg-configure-external-volume)
- [Snowflake: Amazon S3 用 external volume の構成](https://docs.snowflake.com/en/user-guide/tables-iceberg-configure-external-volume-s3)
- [Snowflake: 外部ストレージの管理](https://docs.snowflake.com/en/user-guide/tables-iceberg-managing-external-volumes)
- [Snowflake: Horizon Catalog 経由の外部エンジン](https://docs.snowflake.com/en/user-guide/tables-iceberg-access-using-external-query-engine-snowflake-horizon)
- [Snowflake Terraform provider: external_volume](https://registry.terraform.io/providers/snowflakedb/snowflake/latest/docs/resources/external_volume)
- [Snowflake Terraform provider: schema](https://registry.terraform.io/providers/snowflakedb/snowflake/latest/docs/resources/schema)

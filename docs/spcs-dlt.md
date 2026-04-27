# SPCS + dlt によるデータロードパイプライン

## 概要

Snowpark Container Services（SPCS）上で [dlt（data load tool）](https://dlthub.com) を動かし、外部データソースから Snowflake にデータをロードするパイプラインの構成です。

### なぜ SPCS で dlt を動かすか

dlt をストアドプロシージャ内で動かすと以下の制約があります：

- Snowflake の Anaconda チャンネルにあるパッケージしか使えない
- dlt の destination（書き込み先）設定が困難で、state 管理・スキーマ管理が使えない
- 認証情報の安全な管理が難しい

SPCS を使うことで：

- Docker コンテナなので任意のパッケージが使える
- dlt を本来の使い方（destination + state 管理）で動かせる
- Snowflake Secrets で認証情報を安全に管理できる

---

## アーキテクチャ

```
外部 API（例: JSONPlaceholder）
        ↓ HTTPS（External Network Access 経由）
SPCS Job（Docker コンテナ）
  └─ dlt pipeline
        ↓ HTTPS（External Network Access 経由）① Snowflake に接続
Snowflake
        ↓ 内部ステージの PUT URL を発行
SPCS Job（Docker コンテナ）
        ↓ HTTPS（External Network Access 経由）② S3 にファイルをアップロード
S3 内部ステージ（sfc-jp-ds1-24-customer-stage.s3.amazonaws.com）
        ↓ COPY INTO
Snowflake
  ├─ raw.posts               # ロードされたデータ
  ├─ raw._dlt_loads          # ロード履歴
  └─ raw._dlt_pipeline_state # インクリメンタルロードの state
```

### ポイント：dlt の Snowflake destination はデータを直接書き込まない

dlt は Snowflake にデータを INSERT するのではなく、以下の2ステップでロードします：

1. データファイル（gzip 圧縮 JSONL）を Snowflake の**内部ステージ（S3）に直接 PUT**
2. Snowflake が S3 からテーブルに **COPY INTO** で取り込む

このため SPCS コンテナから Snowflake だけでなく **S3 エンドポイントへの HTTPS アクセスも必要**です。S3 のホスト名はアカウントのリージョンによって異なります（例: `sfc-jp-ds1-24-customer-stage.s3.amazonaws.com`）。

---

## ファイル構成

```
snowflake/
  spcs/
    dlt/
      Dockerfile     # コンテナイメージの定義
      pipeline.py    # dlt パイプライン本体
      spec.yaml      # SPCS Job の仕様（テンプレート）
  spcs_setup.sql     # Snowflake 側の全セットアップ SQL
```

---

## セットアップ手順

### 1. Docker イメージのビルドと push

#### Docker レジストリについて

通常の `docker login`（引数なし）は Docker Hub に認証します。Snowflake のイメージレジストリに push するには、`snow spcs image-registry login` を使って Snowflake のレジストリ宛ての認証情報を取得します。

```bash
snow spcs image-registry login --connection <CONNECTION_NAME>
```

これにより `~/.docker/config.json` に `szebenz-os44603.registry.snowflakecomputing.com` の認証情報が追加されます。Docker Hub の認証とは別管理なので、通常の `docker pull` 等には影響しません。

#### アーキテクチャについて

SPCS は `amd64` アーキテクチャのイメージが必要です。Apple Silicon（M1/M2/M3）Mac でビルドする場合は `--platform linux/amd64` を必ず指定してください。指定しないと `exec format error` でコンテナが起動しません。

```bash
# amd64 向けにビルド
docker build --platform linux/amd64 \
  -t szebenz-os44603.registry.snowflakecomputing.com/dlt_demo/public/my_repo/dlt-pipeline:latest \
  ./spcs/dlt

# push
docker push szebenz-os44603.registry.snowflakecomputing.com/dlt_demo/public/my_repo/dlt-pipeline:latest
```

### 2. Snowflake 側のセットアップ

`spcs_setup.sql` を以下の順番で実行します。`<>` のプレースホルダーは環境に合わせて置き換えてください。

| プレースホルダー | 説明 |
|---|---|
| `<RSA_PUBLIC_KEY>` | ローカルで生成した公開鍵の中身（ヘッダー・フッター除く） |
| `<RSA_PRIVATE_KEY>` | ローカルで生成した秘密鍵の全内容（ヘッダー・フッター含む） |

実行順序：

1. データベース・スキーマの作成
2. イメージレジストリの作成
3. ウェアハウスの作成
4. ロール・ユーザーの作成
5. Secret の作成
6. コンピュートプールの作成（`ACTIVE` になるまで待つ）
7. spec.yaml アップロード用 Stage の作成
8. External Network Access の設定
9. spec.yaml を Stage にアップロード（ローカルで実行）
10. Job の実行

### 3. spec.yaml を Stage にアップロード

SQL 実行前にローカルから以下のコマンドで `spec.yaml` を Snowflake Stage にアップロードします：

```bash
snow sql \
  -q "PUT file://$(pwd)/spcs/dlt/spec.yaml @dlt_demo.public.spcs_specs AUTO_COMPRESS=FALSE OVERWRITE=TRUE" \
  --connection admin_connection
```

`spec.yaml` を変更した場合も同じコマンドで上書きアップロードできます（`OVERWRITE=TRUE`）。

### 4. Job の実行

Stage にアップロードした `spec.yaml` を直接参照して実行します。

```sql
EXECUTE JOB SERVICE
  IN COMPUTE POOL dlt_pool
  NAME = dlt_demo.public.dlt_jsonplaceholder_job
  EXTERNAL_ACCESS_INTEGRATIONS = (jsonplaceholder_integration)
  FROM @dlt_demo.public.spcs_specs SPECIFICATION_FILE = 'spec.yaml';
```

構文のポイント：`FROM @<stage> SPECIFICATION_FILE = '<ステージ内のパス>'` の形式で、`@` はステージ名の前に置き、ファイルパスは `SPECIFICATION_FILE =` に分けて指定します。

---

## spec.yaml の本来の使い方（ベストプラクティス）

spec ファイルの参照方法として以下の2つがあります。

### 方法 1：Snowflake Stage から直接参照

```sql
-- spec.yaml を Stage にアップロード
PUT file:///path/to/spcs/dlt/spec.yaml @dlt_demo.public.my_stage AUTO_COMPRESS=FALSE;

-- Stage 上のファイルを直接指定して Job を実行
EXECUTE JOB SERVICE
  IN COMPUTE POOL dlt_pool
  NAME = dlt_demo.public.dlt_jsonplaceholder_job
  EXTERNAL_ACCESS_INTEGRATIONS = (jsonplaceholder_integration)
  FROM SPECIFICATION_FILE = '@dlt_demo.public.my_stage/spec.yaml';
```

### 方法 2：Snowflake CLI から直接指定（`CREATE SERVICE` 向け）

```bash
snow spcs service create dlt_jsonplaceholder_job \
  --spec-path ./spcs/dlt/spec.yaml \
  --compute-pool dlt_pool
```

### 注意：構文は `FROM @<stage> SPECIFICATION_FILE = '<path>'`

`EXECUTE JOB SERVICE` でも Stage からの参照は可能ですが、構文が特殊です。`@stage` は `FROM` の直後に置き、`SPECIFICATION_FILE =` にはステージ内のファイルパスのみ指定します。

CI/CD に組み込む際は、`spec.yaml` を Stage にアップロードしてからこの構文で実行する流れが自然です。

---

## dlt の認証情報の渡し方

キーペア認証を使用しています。パスワード認証はアカウントの MFA ポリシーで弾かれるため使えません。

### spec.yaml での設定

```yaml
secrets:
  # Snowflake Secret（GENERIC_STRING）から環境変数に注入
  - snowflakeSecret: dlt_demo.public.dlt_snowflake_user
    envVarName: SNOWFLAKE_USER
  - snowflakeSecret: dlt_demo.public.dlt_snowflake_private_key
    envVarName: SNOWFLAKE_PRIVATE_KEY
env:
  # 非機密情報は平文で定義
  SNOWFLAKE_HOST: "szebenz-os44603"       # アカウント識別子のみ（フルドメイン不可）
  SNOWFLAKE_DATABASE: "dlt_demo"
  SNOWFLAKE_WAREHOUSE: "dlt_wh"
  SNOWFLAKE_ROLE: "dlt_role"
```

### pipeline.py での受け取り

```python
credentials = {
    "host": os.environ["SNOWFLAKE_HOST"],
    "database": os.environ["SNOWFLAKE_DATABASE"],
    "username": os.environ["SNOWFLAKE_USER"],
    "private_key": os.environ["SNOWFLAKE_PRIVATE_KEY"],  # PEM 文字列をそのまま渡す
    "warehouse": os.environ["SNOWFLAKE_WAREHOUSE"],
    "role": os.environ["SNOWFLAKE_ROLE"],
}
```

### Snowflake Secret の作成

```sql
-- ユーザー名
CREATE OR REPLACE SECRET dlt_demo.public.dlt_snowflake_user
  TYPE = GENERIC_STRING
  SECRET_STRING = 'dlt_user';

-- 秘密鍵（-----BEGIN PRIVATE KEY----- から -----END PRIVATE KEY----- まで全て含める）
CREATE OR REPLACE SECRET dlt_demo.public.dlt_snowflake_private_key
  TYPE = GENERIC_STRING
  SECRET_STRING = '<RSA_PRIVATE_KEY>';
```

---

## 実行結果の確認

```sql
-- ロードされたデータ
SELECT * FROM raw.posts LIMIT 10;

-- ロード履歴（dlt が自動管理）
SELECT * FROM raw._dlt_loads ORDER BY inserted_at DESC LIMIT 10;

-- パイプラインの state（インクリメンタルロードに使用）
SELECT * FROM raw._dlt_pipeline_state ORDER BY created_at DESC LIMIT 10;

-- Job のログ確認
SELECT SYSTEM$GET_SERVICE_LOGS('dlt_demo.public.dlt_jsonplaceholder_job', 0, 'dlt-pipeline', 100);
```

---

## 必要な権限

### 1. SQL セットアップ実行ユーザー（`spcs_setup.sql` を実行するユーザー）

| 操作 | 必要な権限・ロール |
|---|---|
| `CREATE DATABASE` | `SYSADMIN` |
| `CREATE SCHEMA` | データベースへの `CREATE SCHEMA` |
| `CREATE WAREHOUSE` | `SYSADMIN` |
| `CREATE ROLE` | `USERADMIN` |
| `CREATE USER` | `USERADMIN` |
| `GRANT ROLE TO USER` | `USERADMIN` |
| `GRANT`（warehouse/database/schema） | `SECURITYADMIN` または対象オブジェクトの OWNERSHIP |
| `CREATE IMAGE REPOSITORY` | スキーマへの `CREATE IMAGE REPOSITORY` |
| `CREATE SECRET` | スキーマへの `CREATE SECRET` |
| `CREATE COMPUTE POOL` | **`ACCOUNTADMIN`** |
| `CREATE EXTERNAL ACCESS INTEGRATION` | **`ACCOUNTADMIN`** |
| `EXECUTE JOB SERVICE` | コンピュートプールへの `USAGE` |

`CREATE COMPUTE POOL` と `CREATE EXTERNAL ACCESS INTEGRATION` が `ACCOUNTADMIN` 必須のため、**このユーザーには `ACCOUNTADMIN` ロールが必要**です。

### 2. Snowflake CLI ユーザー（`snow spcs image-registry login` / `docker push` に使うユーザー）

Docker イメージをイメージレジストリに push するためだけに必要な権限です。

| 対象 | 必要な権限 |
|---|---|
| `dlt_demo` データベース | `USAGE` |
| `dlt_demo.public` スキーマ | `USAGE` |
| `dlt_demo.public.my_repo`（イメージリポジトリ） | `READ`, `WRITE` |

```sql
GRANT USAGE ON DATABASE dlt_demo TO ROLE <CLI用ロール>;
GRANT USAGE ON SCHEMA dlt_demo.public TO ROLE <CLI用ロール>;
GRANT READ, WRITE ON IMAGE REPOSITORY dlt_demo.public.my_repo TO ROLE <CLI用ロール>;
```

---

## 躓きポイント

### Docker・イメージ関連

**CI（GitHub Actions）でのイメージ push 時にレジストリ URL は小文字でなければならない**
- `snow spcs image-registry login` が `~/.docker/config.json` に保存する認証情報のキーは常に小文字（例: `szebenz-os44603.registry.snowflakecomputing.com`）
- GitHub Secrets に `SNOWFLAKE_ORGANIZATION` / `SNOWFLAKE_ACCOUNT` を大文字で登録している場合、レジストリ URL が大文字になり Docker の認証情報検索でキーが一致しなくなる
- Docker は認証情報を見つけられず Authorization ヘッダーを送らないため `UNAUTHORIZED_AUTHZ_HEADER_ABSENT` エラーが発生する
- ワークフロー内で `echo "REGISTRY=${REGISTRY,,}" >> $GITHUB_ENV` により小文字に変換して解決できる

**Apple Silicon Mac では `--platform linux/amd64` が必要**
- 指定しないと SPCS 上で `exec format error` が発生してコンテナが起動しない
- SPCS は `amd64` アーキテクチャのみ対応

**`docker login` に直接パスワードを入力すると MFA エラーになる**
- `snow spcs image-registry login --connection <name>` を使うことで MFA をバイパスできる
- 通常の `docker login <registry>` はパスワード直接入力になるため MFA が適用される

---

### Snowflake CLI 認証関連

**設定ファイルの場所が異なる（Mac）**
- `~/.snowflake/config.toml` ではなく `~/Library/Application Support/snowflake/config.toml`

**`externalbrowser` は SAML/SSO が設定されているアカウント専用**
- SAML 未設定のアカウントでは `Invalid connection configuration` エラーになる
- キーペア認証（`authenticator = "SNOWFLAKE_JWT"`）が安定して動作する

**`private_key_path` を指定する場合は `authenticator = "SNOWFLAKE_JWT"` が必須**
- 指定しないと `Private Key authentication requires authenticator set to SNOWFLAKE_JWT` エラー

---

### External Network Access 関連

**SPCS コンテナは Snowflake 内部にあっても外部通信はすべて ENA で許可が必要**
- 「Snowflake の中で動いているから Snowflake には繋がる」は誤り
- コンテナのネットワークは完全に隔離されている

**必要な通信先は3つある**

| 通信先 | 用途 |
|---|---|
| データソース（例: `jsonplaceholder.typicode.com`） | 外部 API からのデータ取得 |
| Snowflake エンドポイント（`<account>.snowflakecomputing.com`） | dlt が Snowflake に接続するため |
| S3 内部ステージ（`sfc-*-customer-stage.s3.amazonaws.com`） | dlt がデータファイルをアップロードするため |

**S3 のホスト名はアカウントのリージョンによって異なる**
- エラーログに出てくる URL から確認する（例: `sfc-jp-ds1-24-customer-stage.s3.amazonaws.com`）

---

### dlt 接続・認証関連

**dlt の環境変数自動検出（`DESTINATION__SNOWFLAKE__CREDENTIALS__*`）が効かない場合がある**
- SPCS の spec.yaml 経由で注入した環境変数が dlt に認識されないケースがあった
- `pipeline.py` で明示的に `os.environ` から読み取って credentials に渡す方が確実

**`host` にはアカウント識別子のみ指定する**
- `szebenz-os44603.snowflakecomputing.com` ではなく `szebenz-os44603` のみ
- dlt が内部で `.snowflakecomputing.com` を自動付加する（フルドメインを渡すと二重になる）

**`private_key` には PEM 文字列をそのまま渡す**
- `cryptography` ライブラリでデコードしたオブジェクトを渡すと `TypeError` が発生する
- dlt が内部でデコードを行うため、PEM 文字列（`-----BEGIN PRIVATE KEY-----...`）をそのまま渡す

**サービスアカウントにもアカウントの MFA ポリシーが適用される**
- `dlt_user` もパスワード認証では MFA が要求されてしまう
- キーペア認証（RSA）を使うことで MFA をバイパスできる

---

### SPCS spec 関連

**`FROM SPECIFICATION_FILE` の構文が `CREATE SERVICE` と異なる**
- 誤：`FROM SPECIFICATION_FILE = '@stage/spec.yaml'`
- 正：`FROM @<stage> SPECIFICATION_FILE = '<ステージ内のパス>'`
- `@` はステージ名の前に置き、`SPECIFICATION_FILE =` にはステージ内のパスのみ指定する

---

### 権限関連

**ACCOUNTADMIN / SYSADMIN でも他ロールが所有するテーブルへの SELECT は自動では持てない**
- Snowflake はオブジェクトの OWNER が権限を管理する設計
- `dlt_role` が作成したテーブルは `dlt_role` が OWNER のため、SYSADMIN でも SELECT できない
- `GRANT ROLE dlt_role TO ROLE SYSADMIN` で `dlt_role` を SYSADMIN 配下に入れることで解決

---

## コスト最適化

- `INSTANCE_FAMILY = CPU_X64_XS`（最小構成）を使用
- `AUTO_SUSPEND_SECS = 300` でコンピュートプールを自動停止
- バッチ処理なので常駐 Service ではなく **Job**（`EXECUTE JOB SERVICE`）として実行
  - Job は処理完了後にコンテナが終了するため、長時間課金が発生しない

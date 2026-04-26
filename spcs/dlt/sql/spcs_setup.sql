-- ============================================================
-- SPCS + dlt セットアップ
-- ※ <RSA_PUBLIC_KEY>, <RSA_PRIVATE_KEY> は環境に合わせて置き換えてください
--
-- 事前にローカルで実行が必要なコマンド:
--   # 1. キーペアの生成
--   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out /tmp/dlt_user.p8 -nocrypt
--   openssl rsa -in /tmp/dlt_user.p8 -pubout -out /tmp/dlt_user.pub
--
--   # 2. Docker イメージのビルドと push
--   snow spcs image-registry login --connection admin_connection
--   docker build --platform linux/amd64 \
--     -t szebenz-os44603.registry.snowflakecomputing.com/dlt_demo/public/my_repo/dlt-pipeline:latest \
--     ./spcs/dlt
--   docker push szebenz-os44603.registry.snowflakecomputing.com/dlt_demo/public/my_repo/dlt-pipeline:latest
--
--   # 3. spec.yaml を Stage にアップロード（Step 8 の後に実行）
--   snow sql -q "PUT file://$(pwd)/spcs/dlt/spec.yaml @dlt_demo.public.spcs_specs AUTO_COMPRESS=FALSE OVERWRITE=TRUE" \
--     --connection admin_connection
-- ============================================================


-- 1. データベース・スキーマの作成（デモ用）

CREATE DATABASE IF NOT EXISTS dlt_demo;
CREATE SCHEMA IF NOT EXISTS dlt_demo.public;
CREATE SCHEMA IF NOT EXISTS dlt_demo.raw;


-- 2. イメージレジストリの作成

CREATE IMAGE REPOSITORY IF NOT EXISTS dlt_demo.public.my_repo;

-- レジストリの URL を確認（docker push 先として使用）
SHOW IMAGE REPOSITORIES IN SCHEMA dlt_demo.public;


-- 3. ウェアハウスの作成

CREATE WAREHOUSE IF NOT EXISTS dlt_wh
  WAREHOUSE_SIZE = XSMALL
  AUTO_SUSPEND = 60
  INITIALLY_SUSPENDED = TRUE
  auto_resume = TRUE
;


-- 4. dlt 用ロール・ユーザーの作成

CREATE ROLE IF NOT EXISTS dlt_role;

GRANT USAGE ON WAREHOUSE dlt_wh TO ROLE dlt_role;
GRANT USAGE ON DATABASE dlt_demo TO ROLE dlt_role;
GRANT USAGE ON SCHEMA dlt_demo.public TO ROLE dlt_role;
GRANT USAGE, CREATE TABLE ON SCHEMA dlt_demo.raw TO ROLE dlt_role;

CREATE USER IF NOT EXISTS dlt_user
  PASSWORD = 'UEFb4(Zf7F@N'
  DEFAULT_ROLE = dlt_role
  DEFAULT_WAREHOUSE = dlt_wh;

GRANT ROLE dlt_role TO USER dlt_user;

-- SYSADMIN 配下に入れることで、dlt_role が作成したオブジェクトに SYSADMIN からアクセス可能になる
GRANT ROLE dlt_role TO ROLE SYSADMIN;

-- キーペア認証の設定（ローカルで生成した公開鍵の中身を貼り付ける）
-- ヘッダー・フッター（-----BEGIN/END PUBLIC KEY-----）は除く
ALTER USER dlt_user SET RSA_PUBLIC_KEY='<RSA_PUBLIC_KEY>';


-- 5. Snowflake Secret の作成（dlt が Snowflake に接続するための認証情報）

-- ユーザー名
CREATE OR REPLACE SECRET dlt_demo.public.dlt_snowflake_user
  TYPE = GENERIC_STRING
  SECRET_STRING = 'dlt_user';

-- 秘密鍵（-----BEGIN PRIVATE KEY----- から -----END PRIVATE KEY----- まで全て含める）
CREATE OR REPLACE SECRET dlt_demo.public.dlt_snowflake_private_key
  TYPE = GENERIC_STRING
  SECRET_STRING = '<RSA_PRIVATE_KEY>';


-- 6. コンピュートプールの作成

CREATE COMPUTE POOL IF NOT EXISTS dlt_pool
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_SUSPEND_SECS = 60
  INITIALLY_SUSPENDED = TRUE
;

-- コンピュートプールの状態確認（ACTIVE になるまで待つ）
DESCRIBE COMPUTE POOL dlt_pool;


-- 7. spec.yaml アップロード用 Stage の作成

CREATE STAGE IF NOT EXISTS dlt_demo.public.spcs_specs
  DIRECTORY = (ENABLE = TRUE);


-- 8. External Network Access の設定

-- JSONPlaceholder API（データソース）
CREATE OR REPLACE NETWORK RULE dlt_demo.public.jsonplaceholder_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('jsonplaceholder.typicode.com:443');

-- Snowflake 自身（dlt の destination として接続するため）
CREATE OR REPLACE NETWORK RULE dlt_demo.public.snowflake_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('szebenz-os44603.snowflakecomputing.com:443');

-- S3 内部ステージ（dlt がデータファイルをアップロードするため）
CREATE OR REPLACE NETWORK RULE dlt_demo.public.s3_stage_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('sfc-jp-ds1-24-customer-stage.s3.amazonaws.com:443');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION jsonplaceholder_integration
  ALLOWED_NETWORK_RULES = (
    dlt_demo.public.jsonplaceholder_rule,
    dlt_demo.public.snowflake_rule,
    dlt_demo.public.s3_stage_rule
  )
  ENABLED = TRUE;


-- 9. Job として実行
--    事前にローカルで spec.yaml を Stage にアップロードしておく（ヘッダーコメント参照）

EXECUTE JOB SERVICE
  IN COMPUTE POOL dlt_pool
  NAME = dlt_demo.public.dlt_jsonplaceholder_job
  EXTERNAL_ACCESS_INTEGRATIONS = (jsonplaceholder_integration)
  FROM @dlt_demo.public.spcs_specs SPECIFICATION_FILE = 'spec.yaml';


-- 10. ログの確認

SELECT SYSTEM$GET_SERVICE_LOGS('dlt_demo.public.dlt_jsonplaceholder_job', 0, 'dlt-pipeline', 100);


-- 11. 結果確認

SELECT * FROM dlt_demo.raw.posts LIMIT 10;

-- dlt が自動で作成する管理テーブル
SELECT * FROM dlt_demo.raw._dlt_loads ORDER BY inserted_at DESC LIMIT 10;
SELECT * FROM dlt_demo.raw._dlt_pipeline_state ORDER BY created_at DESC LIMIT 10;


-- ログの再確認（エラーがあった場合）
SELECT SYSTEM$GET_SERVICE_LOGS('dlt_demo.public.dlt_jsonplaceholder_job', 0, 'dlt-pipeline', 100);


-- ============================================================
-- Job の再実行手順
-- ============================================================
-- 1. spec.yaml を変更した場合は Stage に再アップロード
--    snow sql -q "PUT file://$(pwd)/spcs/dlt/spec.yaml @dlt_demo.public.spcs_specs AUTO_COMPRESS=FALSE OVERWRITE=TRUE" \
--      --connection admin_connection
--
-- 2. 既存 Job を削除して再実行
--    DROP SERVICE dlt_demo.public.dlt_jsonplaceholder_job;
--    → Step 9 の EXECUTE JOB SERVICE を再実行


-- ============================================================
-- クリーンアップ（デモ終了後にまとめて削除）
-- ============================================================

-- DROP DATABASE dlt_demo;  -- データ・スキーマ・Secret・レジストリ・ネットワークルール・Stage をまとめて削除
-- DROP WAREHOUSE dlt_wh;
-- DROP COMPUTE POOL dlt_pool;
-- DROP EXTERNAL ACCESS INTEGRATION jsonplaceholder_integration;
-- DROP USER dlt_user;
-- DROP ROLE dlt_role;

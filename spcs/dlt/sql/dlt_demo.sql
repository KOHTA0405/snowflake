-- ============================================================
-- dlt demo: JSONPlaceholder API -> Snowflake
-- ============================================================

-- 1. External Network Access の設定

CREATE OR REPLACE NETWORK RULE jsonplaceholder_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('jsonplaceholder.typicode.com:443');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION jsonplaceholder_integration
  ALLOWED_NETWORK_RULES = (jsonplaceholder_rule)
  ENABLED = TRUE;


-- 2. ストアドプロシージャの作成

CREATE OR REPLACE PROCEDURE load_posts_with_dlt()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.9'
PACKAGES = ('snowflake-snowpark-python', 'dlt', 'requests')
EXTERNAL_ACCESS_INTEGRATIONS = (jsonplaceholder_integration)
HANDLER = 'run'
AS $$
import dlt
import requests

@dlt.resource(name="posts")
def get_posts():
    response = requests.get("https://jsonplaceholder.typicode.com/posts")
    response.raise_for_status()
    yield from response.json()

def run(session):
    # dlt でデータを抽出
    data = list(get_posts())

    # Snowpark でテーブルに書き込み
    df = session.create_dataframe(data)
    df.write.save_as_table("dlt_posts", mode="overwrite")

    return f"Loaded {len(data)} rows"
$$;


-- 3. 実行

CALL load_posts_with_dlt();

-- 確認
SELECT * FROM dlt_posts LIMIT 10;

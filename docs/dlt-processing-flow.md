# dlt の内部処理フロー：一般系（dict/ジェネレータ）vs DataFrame/Arrow 系

## 概要

dlt（data load tool）はデータソースから宛先（このリポジトリでは Snowflake）にデータを送る際、常に **Extract → Normalize → Load** の3フェーズを実行する。`@dlt.resource` 関数が何の型を `yield` するかによって、この3フェーズの中身、特に Normalize フェーズの処理量が大きく変わる。

本ドキュメントでは [`spcs/dlt/pipeline.py`](../spcs/dlt/pipeline.py) の `get_posts()` を題材に、

- 辞書（dict）/ジェネレータを `yield` する **一般系**
- pandas DataFrame や `pyarrow.Table` を `yield` する **DataFrame/Arrow 系**

の処理の流れと違いを整理する。SPCS 上での運用・セットアップ手順は [`spcs-dlt.md`](./spcs-dlt.md) を参照。

参考: [dlt公式ドキュメント - Arrow table and Pandas](https://dlthub.com/docs/dlt-ecosystem/verified-sources/arrow-pandas)

---

## 前提：`yield` とは

`yield` を含む関数（ジェネレータ関数）は、呼び出しても即座には実行されず、「値を1つ取り出すたびに、その場所まで実行して一時停止する」イテレータを返す。`return` のように結果をまとめて一気に返すのではなく、必要な分だけ順に生成できるため、大量データを扱う際にメモリ効率が良い。

```python
def get_posts():
    yield from response.json()  # dict を1件ずつ順に渡す
```

dlt の `@dlt.resource` 関数がジェネレータであるのは、この「1件ずつ流す」性質を Extract フェーズで活かすためである。

---

## dlt 全体のフェーズ構成（共通）

```
[リソース関数]
      ↓
  Extract   ソースからデータを取得し、ローカルに一次保存
      ↓
  Normalize スキーマ推論・型変換・列名正規化・管理カラム付与
      ↓
  Load      Snowflake の内部ステージへアップロード → COPY INTO
```

どちらの系でも上記3フェーズの構造自体は変わらない。違いは **Normalize フェーズで何を計算する必要があるか** に集約される。

---

## 一般系：dict / ジェネレータベース

### 該当コード（このリポジトリの実装）

```python
@dlt.resource(name="posts")
def get_posts():
    response = requests.get("https://jsonplaceholder.typicode.com/posts")
    response.raise_for_status()
    yield from response.json()
```

### サンプルソースデータ（3行）

```json
[
  {"userId": 1, "id": 1, "title": "sunt aut facere",   "body": "quia et suscipit..."},
  {"userId": 1, "id": 2, "title": "qui est esse",       "body": "est rerum tempore..."},
  {"userId": 2, "id": 3, "title": "ea molestias quasi", "body": "et iusto sed quo..."}
]
```

### 1. Extract

`response.json()` の各要素（dict）が `yield` され、dlt はそれを1件ずつローカルの作業ディレクトリに **JSONL** として書き出す。この時点ではキー名は API が返した生の形（`userId` など camelCase）のまま。

```jsonl
{"userId": 1, "id": 1, "title": "sunt aut facere", "body": "quia et suscipit..."}
{"userId": 1, "id": 2, "title": "qui est esse", "body": "est rerum tempore..."}
{"userId": 2, "id": 3, "title": "ea molestias quasi", "body": "et iusto sed quo..."}
```

### 2. Normalize（行単位で発生する処理）

| 処理 | 内容 |
|---|---|
| 列名正規化 | `userId` → `user_id` のように snake_case へリネーム（**1行ずつ**） |
| 型推論 | 各値を見て `BIGINT`/`VARCHAR` 等を判定（**1行ずつ**） |
| ネスト分解 | dict/list のネストがあれば子テーブルへフラット化（**1行ずつ**） |
| 管理カラム付与 | `_dlt_id`（行ハッシュ）と `_dlt_load_id`（実行ID）を追加（**1行ずつ**） |

結果（Parquet化される直前のイメージ）：

| user_id | id | title | body | _dlt_id | _dlt_load_id |
|---|---|---|---|---|---|
| 1 | 1 | sunt aut facere | quia et suscipit... | a1b2c3... | 1755000000.123456 |
| 1 | 2 | qui est esse | est rerum tempore... | d4e5f6... | 1755000000.123456 |
| 2 | 3 | ea molestias quasi | et iusto sed quo... | g7h8i9... | 1755000000.123456 |

JSON オブジェクトの集合を、dlt が **Python レベルで逐次パース** しながらテーブル形状に組み立て直している点が特徴。件数が増えるほどこのループ回数が線形に増える。

### 3. Load

1. `raw.posts` が存在しなければ、確定したスキーマから `CREATE TABLE` / 既存なら `ALTER TABLE ADD COLUMN`
2. 正規化済みファイルを Snowflake の内部ステージ（実体は S3）へアップロード
3. `COPY INTO raw.posts FROM @stage ...` でロード
4. `raw._dlt_loads` に完了レコードを1行追加（`load_id`, `status=0` など）

---

## DataFrame / Arrow 系

### 書き換え例

```python
import pandas as pd

@dlt.resource(name="posts")
def get_posts():
    response = requests.get("https://jsonplaceholder.typicode.com/posts")
    response.raise_for_status()
    yield pd.DataFrame(response.json())  # dict のリストではなく DataFrame を丸ごと yield
```

`pyarrow.Table` を直接 `yield` する場合も同様の扱いになる。

### 一般系との違い（フェーズ別）

| フェーズ | 一般系（dict） | DataFrame/Arrow 系 |
|---|---|---|
| Extract | dict を1件ずつ JSONL に書き出し | DataFrame/Arrow テーブルを丸ごと1オブジェクトとして保持 |
| 型推論 | 各値を Python で見て**行ごとに**判定 | **スキップ**。pandas の dtype / Arrow の schema をそのまま dlt のスキーマに変換 |
| 列名正規化 | 行ごとに実施 | 列（スキーマ）に対して1回実施 |
| ネスト分解 | dict のネストを行ごとに検出・分解 | struct/list 型の列に対して列単位で処理 |
| 管理カラム付与 | `_dlt_id`/`_dlt_load_id` を**デフォルトで**1行ずつ Python で追加 | **デフォルトでは付与されない**（後述） |
| 出力ファイル | JSONL 経由で Parquet 化 | Arrow テーブルを**直接** Parquet に書き出し（ゼロコピーに近い） |
| Load | 同じ（内部ステージ PUT → COPY INTO） | 同じ（内部ステージ PUT → COPY INTO） |

dlt 公式ドキュメントの表現を借りると、この系では「dlt bypasses many processing steps normally involved in passing JSON objects through the pipeline」——JSON オブジェクトを1件ずつ処理する工程そのものを迂回する。

### 管理カラム（`_dlt_id` / `_dlt_load_id`）の扱いの違い

Arrow/DataFrame 系では、公式ドキュメントに「dlt does not add any data lineage columns by default when loading Arrow tables」と明記されている通り、**デフォルトでは `_dlt_id`/`_dlt_load_id` は付与されない**。これは単なる実装上の違いではなく、挙動そのものの違いである。

付与したい場合は明示的に設定を有効にする。

```python
add_dlt_load_id = True
add_dlt_id = True
```

有効化した場合でも、2つのカラムでコストが異なる。

- **`_dlt_load_id`**：同一バッチ内は全行同じ値になるため、値1つをN行分の列としてブロードキャストして既存テーブルにくっつけるだけの軽い操作で済む。
- **`_dlt_id`**：行ごとに異なる一意なハッシュが必要なため、単純な定数ブロードキャストでは済まない。公式ドキュメントには「`add_dlt_id` adds the column during the `normalize` stage after the file has been extracted to disk」とあり、一度ディスクに書き出した抽出ファイルを**読み直してカラムを追加し、再書き込みする**という追加の I/O が発生する。一般系のように抽出と同時に1行ずつ付与するのとは異なり、後工程でファイルを開き直すコストがかかる点に注意。

| | 一般系（dict） | DataFrame/Arrow 系 |
|---|---|---|
| デフォルト動作 | `_dlt_id`/`_dlt_load_id` とも自動付与 | どちらも付与されない（オプトイン） |
| `_dlt_load_id`（有効化時） | 1行ずつ Python で代入 | 列全体に同じ値を1回でブロードキャスト（軽量） |
| `_dlt_id`（有効化時） | 1行ずつハッシュ計算して代入 | normalize ステージでファイルを読み直してカラム追加・再書き込み（オーバーヘッドあり） |

#### `add_dlt_id` を有効にすると一般系と同じ速度に戻るのか

公式ドキュメントに一般系（dict）と Arrow+`add_dlt_id` の速度を直接比較した記述はなく、断片的な情報から構造的に推測する他ない。

- `add_dlt_id` で増えるコストは「`_dlt_id` という1カラム分の計算＋ファイルの読み直し・再書き込み1回」であり、一般系のように**全カラムの型推論・キー名正規化・JSON逐次パース・ネスト分解**まで戻ってくるわけではない。したがって理屈の上では一般系より軽いはずである。
- ただし読み直し・再書き込みというI/O自体は軽くはなく、特に大きなファイルではボトルネックになり得るため、「一般系より確実に速い」とも断言できない。ドキュメントに数値的な比較がなく、**正確な優劣は未確認**。
- 実務上は `_dlt_id` が本当に必要かを先に見極めるのが現実的。ソースに自然な主キーがあり `write_disposition="merge"` の `primary_key` として使えるなら `add_dlt_id` は不要なことが多い。ロード実行単位の追跡だけで良い場合は、コストの軽い `add_dlt_load_id` のみ有効にする選択肢もある。

### 制約

- **バッチ間でスキーマが一致している必要がある**：同一リソースから複数回 `yield` する場合、各 DataFrame/Arrow テーブルの列構成・型が揃っていないとエラーになりうる。dict ベースなら dlt が行ごとの差異を吸収してくれるが、この系では吸収されない。
- **Parquet 対応 destination でのみ最適化が効く**：Snowflake・BigQuery・DuckDB・Redshift・Databricks 等は対応。非対応 destination では結局行形式に戻すため恩恵が薄い（本リポジトリの destination は Snowflake なので対応範囲内）。
- 型を厳密にコントロールしたい場合は、取得元（pandas/pyarrow）側で事前にキャストしておく必要がある。dlt 側の柔軟な型推論には頼れない。

### `pyarrow.Table` / `pandas.DataFrame` / `polars.DataFrame` の違い

3つとも「DataFrame/Arrow 系」として同じ最適化パスに乗るが、内部的な扱いには以下の差がある（[dlt公式ドキュメント](https://dlthub.com/docs/dlt-ecosystem/verified-sources/arrow-pandas)より）。

| フォーマット | 内部での扱い |
|---|---|
| `pyarrow.Table` | 変換不要。そのまま抽出処理に渡される（起点となるフォーマット） |
| `pandas.DataFrame` | 内部的に Arrow テーブル相当の形に変換されてから処理される。**pandas のインデックスはデフォルトでは保存されない**（dlt 1.4.1 以降） |
| `polars.DataFrame` / `polars.LazyFrame` | `@dlt.resource` から直接 `yield` すると自動的に Arrow テーブルに変換される。`LazyFrame` の場合は変換前に自動で評価（collect）される |

**パフォーマンス**：ドキュメント上、3フォーマット間の性能差は明言されていない。速度を左右するのは「Parquet 対応 destination かどうか」であり、pandas/polars/arrow のどれを使っても最終的に同じ Arrow 経由の高速パスに乗る。

**複数バッチ結合時の型差異**：同一リソースから複数回 `yield` する際、ファイルごとに pandas が微妙に違う型を推論するようなケースでは、`arrow_concat_promote_options` という設定で型差異の解決方法を制御できる。

**選び方の指針**：性能で選ぶ必要はなく、元データを扱っているライブラリ（既存コード資産や好み）に合わせて pandas / polars / pyarrow のいずれかを選べばよい。

---

## 効率が変わるのはどんな時か

| データ規模 | 一般系 | DataFrame/Arrow 系 |
|---|---|---|
| 数行〜数百行（例：3行、`jsonplaceholder` の実際の100件） | Normalize のコストは誤差レベル。`requests.get()` の通信待ちが支配的で差はほぼ出ない | pandas/pyarrow の import・DataFrame構築コストの方が上回り、**むしろ遅くなることもある** |
| 数万〜数十万行超（ページネーションAPI・DB抽出・CSV/Parquet読み込みなど） | 行ごとの Python ループが積み重なり Normalize がボトルネック化 | 型推論・管理カラム付与が列演算になり、Normalize の実行時間が明確に短縮される |

このリポジトリの SPCS Job（[`spcs_setup.sql`](../spcs/dlt/sql/spcs_setup.sql) で `INSTANCE_FAMILY = CPU_X64_XS` の最小構成）のように CPU が限られた環境では、Normalize の CPU 負荷を減らすことは実行時間だけでなく compute pool の稼働コストにも直結する。データ量が増える見込みがあるリソースでは、DataFrame/Arrow 化を検討する価値がある。

---

## まとめ

- dlt の Extract → Normalize → Load という骨格はどちらの系でも同じ
- 違いは Normalize フェーズで「JSON を1件ずつ Python でパースするか」「列指向データをそのまま流用するか」
- 小規模データ（このリポジトリの `posts` 100件程度）では一般系で十分、書き換えのコストに見合わない
- 大規模データ・CPU 制約のある実行環境では DataFrame/Arrow 系がスループット・コストの両面で有利

# dbt成果物永続化用S3バケット

## 概要

[dbt_snowflake](https://github.com/KOHTA0405/dbt_snowflake)リポジトリでSlim CI(`state:modified`)とPrefectのノード単位キャッシュ(選択的リトライ)を実現するために必要な、dbt成果物永続化用のS3バケットの要件メモ。まだ実装しておらず、Terraformで構築する際の参考として残す。

### 背景・用途

dbt_snowflakeのPrefect flow(`flows/dbt_build_flow.py`)は`PrefectDbtOrchestrator`(PER_NODEモード)でdbtを実行しているが、Prefect Cloudのmanaged実行は毎回使い捨てコンテナのため、明示的に永続化しないと実行終了と同時に消えてしまうデータが2種類ある。

1. **`manifest.json`**: 本番(`prod`ターゲット)の`dbt build`が成功するたびに生成される、その時点の「正しい状態」。CI(PR時)で`dbt build --select state:modified+ --state ./state --defer`のように使い、変更されたモデルとその下流だけを対象にビルドするために必要
2. **ノード単位キャッシュ**: `PrefectDbtOrchestrator`の`cache=CacheConfig(...)`(PER_NODEモード専用)が使うキャッシュストア。内容が変わっていないノードの結果をスキップできるため、一部のモデルだけ失敗した場合に同じflowを再実行するだけで失敗したノード以降だけ再実行される(「特定モデルからretry」に近い体験)

どちらもPrefectの`WritableFileSystem`Block(`S3Bucket`など)経由で読み書きする想定。Snowflake内部ステージも検討したが、ノードキャッシュは「flow実行のたびにノードごとに1回ずつ有無をチェックする」高頻度・多数の小さいオブジェクトへのアクセスになり、Snowflakeセッションのオーバーヘッドが乗ってくるため不向きと判断し、S3に一本化する方針とした。

---

## バケット要件

### 基本設定

| 項目 | 値 |
| --- | --- |
| バケット名 | `kohta0405-dbt-snowflake-artifacts`(S3バケット名はグローバル一意のため、GitHubユーザー名を接頭辞にして衝突を回避) |
| リージョン | 未決定。特にこだわりがなければ`ap-northeast-1`を提案 |
| パブリックアクセス | 完全ブロック(`block_public_acls` / `block_public_policy` / `ignore_public_acls` / `restrict_public_buckets` すべて`true`) |
| デフォルト暗号化 | 有効化(SSE-S3 = `AES256`で十分、KMS必須の要件は今のところ無し) |
| バージョニング | 有効化。`latest`パスへの上書きが基本運用のため、誤って壊れたファイルで上書きした場合の復旧用セーフティネットとして |

### オブジェクトのキー構造

環境ごとにバケットを分けず、1つのバケット内をprefixで分離する(バケットを分けるほどの規模ではなく、IAMポリシーのprefix指定で十分な分離が可能なため)。

```
prod/manifest/manifest.json     # 本番buildのstate(Slim CI比較用)
prod/cache/...                  # PrefectDbtOrchestratorのノードキャッシュ(prod)
dev/cache/...                   # 同上(dev、優先度は低)
```

### ライフサイクルルール

- `*/cache/*`配下: キャッシュキーはノード内容のハッシュ由来のため、モデルを変更するたびに新しいオブジェクトが増え続け、不要になった古いキャッシュが溜まる。一定期間(例: 30日)アクセスが無いオブジェクトを自動削除するルールが必要
- `*/manifest/*`配下: 常に上書きされる単一の最新ファイルなのでライフサイクルルールは不要(バージョニングの世代管理だけで十分)

### IAM(最小権限、用途ごとに分離)

| 主体 | 権限範囲(prefix) | 操作 |
| --- | --- | --- |
| 本番Prefect flow | `prod/*` | Get/Put(manifest書き込み・キャッシュ読み書き) |
| ローカル/dev実行 | `dev/*` | Get/Put(キャッシュ読み書きのみ、任意) |
| CI(GitHub Actions) | `prod/manifest/*` | Get専用(state取得のみ、書き込み権限は持たせない) |

### タグ

- `Project: dbt_snowflake`
- `ManagedBy: terraform`

---

## 未決定事項(実装時に詰める)

- このリポジトリの`terraform/`は現状Snowflakeプロバイダのみで構成されているため、AWSプロバイダの追加設定(認証情報の管理方法含む)が別途必要
- バケットのリージョン
- ノードキャッシュ(`CacheConfig`)を実際に有効化するかどうか、有効化する場合の`retries`等のパラメータ設計は[dbt_snowflake側のSlim CI設計メモ](https://github.com/KOHTA0405/dbt_snowflake/blob/main/docs/ci-cd-slim-ci-plan.md)を参照
- CI用IAM認証情報(GitHub Actionsからの読み取り用)の受け渡し方法(GitHub Secrets等)

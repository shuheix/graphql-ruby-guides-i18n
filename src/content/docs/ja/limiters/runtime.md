---
title: ランタイムリミッター
description: クライアントの GraphQL 操作の総実行時間を制限する
sidebar:
  order: 3
enterprise: true
---
`GraphQL::Enterprise::RuntimeLimiter` は、単一クライアントが消費する処理時間に上限を適用します。これは [Redis](limiters/redis) を使って、[token bucket](https://en.wikipedia.org/wiki/Token_bucket) アルゴリズムで時間を追跡します。

## なぜ？

この limiter は、短時間に多数の短いクエリが発生する場合（[Active Operation Limiter](/limiters/active_operations) で防げる場合もあります）や、少数の長時間実行されるクエリの場合のいずれでも、単一クライアントが過剰に処理時間を消費するのを防ぎます。リクエストカウンタや複雑度計算とは異なり、runtime limiter は受信リクエストの構造を考慮しません。代わりに、リクエスト全体として消費された時間を単純に測定し、クライアントが上限を超えたときにクエリを停止します。

## セットアップ

この limiter を使うには、schema の設定を更新し、クエリに `context[:limiter_key]` を含めてください。

### Schema のセットアップ

schema を設定するには、デフォルトの `limit_ms:` 値と共に `use GraphQL::Enterprise::RuntimeLimiter` を追加します:

```ruby
class MySchema < GraphQL::Schema
  # ...
  use GraphQL::Enterprise::RuntimeLimiter,
    redis: Redis.new(...),
    # Or:
    # connection_pool: ...
    # redis_cluster: ...
    limit_ms: 90 * 1000 # 90 seconds per minute
end
```

`limit_ms: false` を指定すると、この limiter に対しては「制限なし」がデフォルトになります。

また、`window_ms:` オプションも受け付けます。これは `limit_ms:` がクライアントのバケットに加算される期間で、デフォルトは `60_000`（1 分）です。

リクエストが実際に停止される前に、[soft mode](/limiters/deployment#soft-limits) を無効にする必要があります。

### Query のセットアップ

クライアントを制限するために、limiter は各 GraphQL operation ごとにクライアント識別子を必要とします。デフォルトでは `context[:limiter_key]` を確認します:

```ruby
context = {
  viewer: current_user,
  # for example:
  limiter_key: logged_in? ? "user:#{current_user.id}" : "anon-ip:#{request.remote_ip}",
  # ...
}

result = MySchema.execute(query_str, context: context)
```

Operations with the same `context[:limiter_key]` will rate limited in the same buckets. A limiter key is required; if a query is run without one, the limiter will raise an error.

To provide a client identifier another way, see [Customization](#customization).

## カスタマイズ

`GraphQL::Enterprise::RuntimeLimiter` は動作をカスタマイズするためのいくつかのフックを提供します。これらを使うには limiter のサブクラスを作成し、以下のようにメソッドをオーバーライドしてください:

```ruby
# app/graphql/limiters/runtime.rb
class Limiters::Runtime < GraphQL::Enterprise::RuntimeLimiter
  # override methods here
end
```

フックは次の通りです:

- `def limiter_key(query)` は、現在の `query` に対するクライアントを識別する文字列を返すべきです。
- `def limit_for(key, query)` は整数または `nil` を返すべきです。整数が返された場合、その制限が現在のクエリに適用されます。`nil` が返された場合は、現在のクエリに対して制限は適用されません。
- `def soft_limit?(key, query)` は「ソフトモード」の適用をカスタマイズするために実装できます。デフォルトでは redis の設定を確認します。
- `def handle_redis_error(err)` は limiter が Redis からのエラーを rescue したときに呼ばれます。デフォルトでは `warn` に渡され、クエリは停止されません。

## 計測

limiter が組み込まれている間、query context に limiter の動作に関する情報が追加されます。`context[:runtime_limiter]` からアクセスできます:

```ruby
result = MySchema.execute(...)

pp result.context[:runtime_limiter]
# {:key=>"custom-key-9",
#  :limit_ms=>800,
#  :remaining_ms=>0,
#  :soft=>true,
#  :limited=>true,
#  :window_ms=>60_000}
```

返されるのは次のキーを持つ Hash です:

- `key: [String]`、このクエリで使用された limiter key
- `limit_ms: [Integer, nil]`、このクエリに適用された制限
- `remaining_ms: [Integer, nil]`、このクライアントのバケットに残っている時間
- `soft: [Boolean]`、クエリが「ソフトモード」で実行された場合は `true`
- `limited: [Boolean]`、レート制限を超えた場合は `true`（ただし `soft:` も `true` の場合はクエリは停止されません）
- `window_ms: [Integer]`、limiter に設定された `window_ms:` の値

これを使ってアプリケーションの監視システムに詳細なメトリクスを追加できます。例えば:

```ruby
MyMetrics.increment("graphql.runtime_limiter", tags: result.context[:runtime_limiter])
```

## いくつかの注意点

limiter は長時間実行されているフィールドを強制的に中断することはありません。代わりに、クライアントが許可された処理時間を超えた後は新しいフィールドの実行を停止します。これは任意のコードを中断すると I/O 操作に意図しない影響を与える可能性があるためです。詳細は ["Timeout: Ruby's most dangerous API"](https://www.mikeperham.com/2015/05/08/timeout-rubys-most-dangerous-api/) を参照してください。

また、limiter は残り時間をクエリの「開始時」にしか確認せず、残り時間を減らすのはクエリの「終了時」だけです。つまり、同時に実行された複数のクエリが同時に残り時間を消費してしまう可能性があります。この点の挙動を制限するには [Active Operation Limiter](/limiters/active_operations) を利用してください。この実装は基本的にトレードオフです。より細かい更新を行うには Redis との通信が増え、各リクエストへのオーバーヘッドが増加します。
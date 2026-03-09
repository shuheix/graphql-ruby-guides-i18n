---
title: アクティブ操作リミッター
description: 同時に実行される GraphQL 操作の数を制限する
sidebar:
  order: 2
enterprise: true
---
`GraphQL::Enterprise::ActiveOperationLimiter` はクライアントが同時にあまりにも多くの GraphQL 操作を実行することを防ぎます。現在実行中の操作の追跡には [Redis](limiters/redis) を使用します。

## なぜ？

一部のクライアントが突然大量のリクエストを送ってきて、利用可能な Ruby プロセスをすべて占有してしまい、他のクライアントへのサービスが妨げられることがあります。このリミッタは GraphQL レイヤでそれを防ぎ、クライアントが既に多数のクエリを実行している場合にクエリを停止することで、サーバープロセスを他のクライアントのリクエスト向けに確保できるようにします。

## 設定

このリミッタを使用するには、スキーマ設定を更新し、クエリに `context[:limiter_key]` を含めてください。

#### スキーマの設定

スキーマに `use GraphQL::Enterprise::ActiveOperationLimiter` を追加し、デフォルトの `limit:` 値を設定します:

```ruby
class MySchema < GraphQL::Schema
  # ...
  use GraphQL::Enterprise::ActiveOperationLimiter,
    redis: Redis.new(...),
    # Or:
    # connection_pool: ...
    # redis_cluster: ...
    limit: 5
end
```

`limit: false` を指定すると、このリミッタに対しては制限なしがデフォルトになります。

また `stale_request_seconds:` オプションも受け付けます。リミッタはこの値を使って、クラッシュなどの予期しない事態が発生した際にリクエストデータをクリーンアップします。

実際にリクエストが停止される前に、[ソフトモード](/limiters/deployment#soft-limits) を無効にする必要があります。

#### クエリの設定

クライアントごとに制限を行うために、リミッタは各 GraphQL 操作に対してクライアント識別子を必要とします。デフォルトでは `context[:limiter_key]` を参照します:

```ruby
context = {
  viewer: current_user,
  # for example:
  limiter_key: logged_in? ? "user:#{current_user.id}" : "anon-ip:#{request.remote_ip}",
  # ...
}

result = MySchema.execute(query_str, context: context)
```

同じ `context[:limiter_key]` を持つ操作は同じバケットで制限されます。limiter key は必須です。指定せずにクエリを実行すると、リミッタはエラーを発生させます。

別の方法でクライアント識別子を提供する方法は、[カスタマイズ](#カスタマイズ) を参照してください。

## カスタマイズ

GraphQL::Enterprise::ActiveOperationLimiter は挙動をカスタマイズするためのいくつかのフックを提供します。これらを使用するには、リミッタのサブクラスを作成し、以下のようにメソッドをオーバーライドしてください:

```ruby
# app/graphql/limiters/active_operations.rb
class Limiters::ActiveOperations < GraphQL::Enterprise::ActiveOperationsLimiter
  # override methods here
end
```

フックは以下の通りです:

- `def limiter_key(query)` は、現在の `query` のクライアントを識別する文字列を返すべきです。
- `def limit_for(key, query)` は整数か `nil` を返すべきです。整数が返された場合、その制限値が現在のクエリに適用されます。`nil` が返された場合、現在のクエリには制限が適用されません。
- `def soft_limit?(key, query)` は「ソフトモード」の適用をカスタマイズするために実装できます。デフォルトでは Redis の設定をチェックします。
- `def handle_redis_error(err)` は、リミットが Redis からのエラーを rescue したときに呼ばれます。デフォルトでは `warn` に渡され、クエリは停止されません。

## 計測情報

リミッタがインストールされている間、その動作に関する情報がクエリのコンテキストに追加されます。`context[:active_operation_limiter]` でアクセスできます:

```ruby
result = MySchema.execute(...)

pp result.context[:active_operation_limiter]
# {:key=>"user:123", :limit=>2, :soft=>false, :limited=>true}
```

以下を含む Hash を返します:

- `key: [String]`、このクエリで使用された limiter key
- `limit: [Integer, nil]`、このクエリに適用された制限値
- `soft: [Boolean]`、クエリが「ソフトモード」で実行された場合は `true`
- `limited: [Boolean]`、レート制限を超えた場合は `true`（ただし `soft:` が `true` の場合、クエリは停止されません）

例えば、これを使ってアプリのモニタリングに詳細なメトリクスを追加できます:

```ruby
MyMetrics.increment("graphql.active_operation_limiter", tags: result.context[:active_operation_limiter])
```
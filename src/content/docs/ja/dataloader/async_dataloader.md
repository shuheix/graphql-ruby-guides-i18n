---
title: 非同期ソースの実行
description: AsyncDataloaderを使用して外部データを並列に取得する
sidebar:
  order: 5
---
`AsyncDataloader` は [`GraphQL::Dataloader::Source#fetch`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader::Source#fetch) の呼び出しを並列で実行するので、データベースクエリやネットワーク呼び出しなどの外部サービス呼び出しがキューで待つ必要がなくなります。

`AsyncDataloader` を使うには、スキーマで `GraphQL::Dataloader` の代わりに以下を使用してください:

```diff
- use GraphQL::Dataloader
+ use GraphQL::Dataloader::AsyncDataloader
```

__また、__ プロジェクトに [the `async` gem](https://github.com/socketry/async) を追加してください。例えば:

```
bundle add async
```

これで、[`GraphQL::Dataloader::AsyncDataloader`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader::AsyncDataloader) は通常の `Fiber` の代わりに `Async::Task` インスタンスを作成し、`async` gem が並列実行を管理します。

この挙動のデモについては次を参照してください: [https://github.com/rmosolgo/rails-graphql-async-demo](https://github.com/rmosolgo/rails-graphql-async-demo)

_`dataloader.yield` を使って [手動の並列化](/dataloader/parallelism) を実装することもできます。_

## Rails の設定

Rails では、fiber ベースの並行処理を適切にサポートする **Rails 7.1** が必要です。また、Rails を Fiber による分離で動作するよう設定することをおすすめします:

```ruby
class Application < Rails::Application
  # ...
  config.active_support.isolation_level = :fiber
end
```

### ActiveRecord 接続

ActiveRecord の接続処理を改善するために、Dataloader の [Fiber ライフサイクルフック](/dataloader/dataloader#fiber-lifecycle-hooks) を利用できます:

- Rails < 7.2 では、Fiber が終了しても接続は再利用されず、リクエストやバッチジョブが終了したときにのみ再利用されます。手動で `release_connection` を呼ぶことで改善できます。
- `isolation_level = :fiber` を設定すると、新しい Fiber は親 Fiber から `connected_to ...` 設定を継承しません。

まとめると、次のように改善できます:

```ruby
def get_fiber_variables
  vars = super
  # Collect the current connection config to pass on:
  vars[:connected_to] = {
    role: ActiveRecord::Base.current_role,
    shard: ActiveRecord::Base.current_shard,
    prevent_writes: ActiveRecord::Base.current_preventing_writes
  }
  vars
end

def set_fiber_variables(vars)
  connection_config = vars.delete(:connected_to)
  # Reset connection config from the parent fiber:
  ActiveRecord::Base.connecting_to(**connection_config)
  super(vars)
end

def cleanup_fiber
  super
  # Release the current connection
  ActiveRecord::Base.connection_pool.release_connection
end
```

例はご利用のデータベース構成や抽象クラスの階層に合わせて修正してください。

## その他のオプション

Dataloader を使って並列処理を手動で実装することもできます。詳細は [Dataloader の並列化](/dataloader/parallelism) ガイドを参照してください。
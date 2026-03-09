---
title: マルチテナント
description: GraphQL Subscription の実行時におけるテナントの切り替え
sidebar:
  order: 8
---
マルチテナントシステムでは、複数の異なるアカウントのデータを同じサーバ上に保存します。（アカウントは組織、顧客、namespace、ドメインなどの場合があり、これらはすべてテナントです。）[Apartment](https://github.com/influitive/apartment) のようなGemがこの構成を支援しますが、アプリケーション内で実装することも可能です。以下は、GraphQL subscriptions を使用する際のこのアーキテクチャに関するいくつかの考慮点です。

## `context` にテナントを追加する

以下のアプローチではすべて、GraphQL 実行時にテナントを識別するために `context[:tenant]` を使用するので、クエリを実行する前に必ず割り当ててください:

```ruby
context = {
  viewer: current_user,
  tenant: current_user.tenant,
  # ...
}

MySchema.execute(query_str, context: context, ...)
```

## テナントに基づく `subscription_scope`

サブスクリプションが配信されるとき、[`subscription_scope`](subscriptions/subscription_classes#scope) はデータを正しい購読者にルーティングするために使われる要素の一つです。簡単に言えば、受信側の暗黙的な識別子です。マルチテナント構成では、`subscription_scope` はテナントを示す context キーを参照するべきです。例えば:

```ruby
class BudgetWasApproved < GraphQL::Schema::Subscription
  subscription_scope :tenant # This would work with `context[:tenant] => "acme-corp"`
  # ...
end

# Include the scope when `.trigger`ing:
BudgetSchema.subscriptions.trigger(:budget_was_approved, {}, { ... }, scope: "acme-corp")
```

あるいは、`subscription_scope` がテナントに属する何かを指す場合もあります:

```ruby
class BudgetWasApproved < GraphQL::Schema::Subscription
  subscription_scope :project_id # This would work with `context[:project_id] = 1234`
end

# Include the scope when `.trigger`ing:
BudgetSchema.subscriptions.trigger(:budget_was_approved, {}, { ... }, scope: 1234)
```

`project_id` がすべてのテナント間で一意であれば、それも問題なく動作します。ただし、テナント間でサブスクリプションを区別するためには、何らかのスコープが必要です。

## 実行時に使用するテナントの選択

サブスクリプションがデータをロードする必要がある場面はいくつかあります:

- ペイロードを構築するとき（結果を準備するためにデータを取得する場合）
- `ActionCableSubscriptions`: `ActionCable` によってブロードキャストされた JSON 文字列を逆シリアライズするとき
- `PusherSubscriptions` と `AblySubscriptions`: query context を逆シリアライズするとき

これらの各操作は、データを正しくロードするために適切なテナントを選択する必要があります。

ペイロードの構築については、[Traceモジュール](queries/tracing) を使用してください:

```ruby
module TenantSelectionTrace
  def execute_multiplex(multiplex:) # this is the top-level, umbrella event
    context = data[:multiplex].queries.first.context # This assumes that all queries in a multiplex have the same tenant
    MultiTenancy.select_tenant(context[:tenant]) do
      # ^^ your multi-tenancy implementation here
      super # Call through to the rest of execution
    end
  end
end

# ...
class MySchema < GraphQL::Schema
  trace_with(TenantSelectionTrace)
end
```

上のトレーサーは `context[:tenant]` を使って、すべての queries、mutations、subscriptions の実行中にテナントを選択します。

`ActionCable` メッセージの逆シリアライズについては、`.dump(obj)` と `.load(string, context)` を実装する `serializer:` オブジェクトを提供してください:

```ruby
class MultiTenantSerializer
  def self.dump(obj)
    GraphQL::Subscriptions::Serialize.dump(obj)
  end

  def self.load(string, context)
    MultiTenancy.select_tenant(context[:tenant]) do
      GraphQL::Subscriptions::Serialize.load(string)
    end
  end
end

# ...
class MySchema < GraphQL::Schema
  # ...
  use GraphQL::Subscriptions::ActionCableSubscriptions, serializer: MultiTenantSerializer
end
```

上の実装は組み込みのシリアライズアルゴリズムを利用しますが、選択したテナントのコンテキスト内で実行されます。

Pusher と Ably で query の context をロードする場合は、必要に応じて `load_context` メソッドにテナント選択を追加してください:

```ruby
class CustomSubscriptions < GraphQL::Pro::PusherSubscriptions # or `GraphQL::Pro::AblySubscriptions`
  def dump_context(ctx)
    JSON.dump(ctx.to_h)
  end

  def load_context(ctx_string)
    ctx_data = JSON.parse(ctx_string)
    MultiTenancy.select_tenant(ctx_data["tenant"]) do
      # Build a symbol-keyed hash, loading objects from the database if necessary
      # to use a `context: ...`
    end
  end
end
```

このアプローチでは、context ハッシュを構築している間に選択されたテナントがアクティブになります。データベースからオブジェクトをロードする必要がある場合に備えた処理です。
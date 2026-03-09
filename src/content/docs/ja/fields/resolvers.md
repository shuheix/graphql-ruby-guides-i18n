---
title: Resolvers
description: 複雑な fields のための再利用可能で拡張可能な解決ロジック
sidebar:
  order: 2
redirect_from:
- "/fields/functions"
---
[`GraphQL::Schema::Resolver`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Resolver) は、field のシグネチャと解決ロジックを格納するコンテナです。`resolver:` キーワードで field に紐付けることができます:

```ruby
# Use the resolver class to execute this field
field :pending_orders, resolver: PendingOrders
```

内部的には、[`GraphQL::Schema::Mutation`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Mutation) は `Resolver` の特殊なサブクラスです。

## まず自分に問いかけてください

本当に `Resolver` が必要ですか？`Resolver` にロジックを置くことにはいくつかのデメリットがあります:

- GraphQL に結びつくため、アプリ内の通常の Ruby オブジェクトよりテストしにくくなります
- ベースクラスが GraphQL-Ruby 由来なので、上流の変更によってコードの更新が必要になる可能性があります

代替案をいくつか示します:

- 表示ロジック（ソート、フィルタリングなど）はアプリ内の通常の Ruby クラスに入れて、そのクラスをテストする
- そのオブジェクトをメソッド経由で呼び出す、例えば:

```ruby
field :recommended_items, [Types::Item], null: false
def recommended_items
  ItemRecommendation.new(user: context[:viewer]).items
end
```

- 共有する引数が多い場合は、クラスメソッドで field を生成する、例えば:

```ruby
# Generate a field which returns a filtered, sorted list of items
def self.items_field(name, override_options, &block)
  # Prepare options
  default_field_options = { type: [Types::Item], null: false }
  field_options = default_field_options.merge(override_options)
  # Create the field
  field(name, **field_options) do
    argument :order_by, Types::ItemOrder, required: false
    argument :category, Types::ItemCategory, required: false
    # Allow an override block to add more arguments
    instance_eval(&block) if block_given?
  end
end

# Then use the generator to create a field:
items_field(:recommended_items) do |field|
  field.argument :similar_to_product_id, ID, required: false
end
# Implement the field
def recommended_items
  # ...
end
```

コードの整理という観点では、そのクラスメソッドをモジュールに入れて、必要なクラス間で共有することもできます。

- 同じロジックを複数のオブジェクト間で共有したい場合は、Ruby のモジュールと `self.included` フックを使うことを検討してください。例えば:

```ruby
module HasRecommendedItems
  def self.included(child_class)
    # attach the field here
    child_class.field(:recommended_items, [Types::Item], null: false)
  end

  # then implement the field
  def recommended_items
    # ...
  end
end

# Add the field to some objects:
class Types::User < BaseObject
  include HasRecommendedItems # adds the field
end
```

- モジュール方式が適している場合は、[Interfaces](/type_definitions/interfaces) も検討してください。Interfaces も（結局はモジュールなので）オブジェクト間で振る舞いを共有でき、introspection を通じてクライアントにその共通性を公開します。

## いつ本当に resolver が必要か？

では、他により良い選択肢があるにもかかわらず `Resolver` が存在する理由は何でしょうか？いくつかの具体的な利点は次のとおりです:

- Isolation（分離）: `Resolver` はフィールド呼び出しごとにインスタンス化されるため、そのインスタンス変数はそのインスタンスだけに限定されます。もしインスタンス変数を使う必要があるなら、この点は役立ちます。処理が終わった後に値が残らないという保証があります。
- 複雑な Schema 生成: `RelayClassicMutation`（`Resolver` のサブクラス）は、各 mutation 用の input type や return type を生成します。`Resolver` クラスを使うと、このコード生成ロジックを実装・共有・拡張しやすくなります。

## `resolver` の使い方

ベースの resolver クラスを使います:

```ruby
module Resolvers
  class RecommendedItems < BaseResolver
    type [Types::Item], null: false
    description "Items this user might like"

    argument :order_by, Types::ItemOrder, required: false
    argument :category, Types::ItemCategory, required: false

    def resolve(order_by: nil, category: nil)
      # call your application logic here:
      recommendations = ItemRecommendation.new(
        viewer: context[:viewer],
        recommended_for: object,
        order_by: order_by,
        category: category,
      )
      # return the list of items
      recommendations.items
    end
  end
end
```

そして field に紐付けます:

```ruby
class Types::User < Types::BaseObject
  field :recommended_items, resolver: Resolvers::RecommendedItems
end
```

`Resolver` のライフサイクルは GraphQL ランタイムによって管理されるため、テストする最良の方法は GraphQL クエリを実行して結果を検証することです。

### 同じタイプの resolver をネストする場合

resolver を、その resolver が返す type の定義内で使うと、循環的なロードの問題に遭遇することがあります。例えば:

```ruby
# app/graphql/types/query_type.rb

module Types
  class QueryType < Types::BaseObject
    field :tasks, resolver: Resolvers::TasksResolver
  end
end

# app/graphql/types/task_type.rb

module Types
  class TaskType < Types::BaseObject
    field :title, String, null: false
    field :tasks, resolver: Resolvers::TasksResolver
  end
end

# app/graphql/resolvers/tasks_resolver.rb

module Resolvers
  class TasksResolver < BaseResolver
    type [Types::TaskType], null: false

    def resolve
      []
    end
  end
end
```

この例は次のようなエラーを引き起こすことがあります: `Failed to build return type for Task.tasks from nil: Unexpected type input:  (NilClass)`。

簡単な解決策は、resolver 内で type を文字列として表現することです:

```ruby
module Resolvers
  class TasksResolver < BaseResolver
    type "[Types::TaskType]", null: false

    def resolve
      []
    end
  end
end
```

こうすることで、ネストされた resolver がロードされるまで type クラスのロードを遅延させられます。

## 拡張（Extensions）

resolver が解決する field に拡張を追加したい場合は、拡張クラスとオプションを受け取る `extension` メソッドを使えます。1 つの resolver に対して複数の拡張を設定できます。

```ruby
class GreetingExtension < GraphQL::Schema::FieldExtension
  def resolve(object:, arguments:, **rest)
    name = yield(object, arguments)
    "#{options[:greeting]}, #{name}!"
  end
end

class ResolverWithExtension < BaseResolver
  type String, null: false

  extension GreetingExtension, greeting: "Hi"

  def resolve
    "Robert"
  end
end
```
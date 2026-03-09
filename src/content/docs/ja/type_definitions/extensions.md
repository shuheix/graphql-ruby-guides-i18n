---
title: GraphQL-Ruby の Type 定義システムの拡張
description: DSL にメタデータやカスタムヘルパーを追加する
sidebar:
  order: 8
redirect_from:
- "/schema/extending_the_dsl/"
---
アプリに GraphQL を統合する際、定義 DSL をカスタマイズできます。例えば、次のようなことが可能です:

- 異なる types や fields に「責任範囲」を割り当てる
- types と fields 間で共通のロジックを DRY にする
- authorization 時に使用するメタデータを付与する

このガイドでは、クラスベースの定義 API を拡張するためのさまざまなオプションを説明します。これらのアプローチは API の成熟に伴って変わる可能性があることに注意してください。問題がある場合は、GitHub で issue を開いて助けを求めることを検討してください。

注: この文書は GraphQL-Ruby 1.10+ におけるベストプラクティスを説明します。古いバージョンの schema をカスタマイズする場合は、GitHub でこのページの古いバージョンを参照してください。

## カスタマイズの概要

一般的に、schema の定義プロセスは次のようになります:

- アプリケーションは多くの GraphQL のクラスを定義する
- root types（`query`、`mutation`、および `subscription`）と定義された `orphan_types` から始めて、schema は schema 内のすべての types、fields、arguments、enum values、および directives を検出する
- 非 type オブジェクト（fields、arguments、enum values）は、それらが属するクラスやインスタンスにアタッチされるときに初期化される

## type 定義のカスタマイズ

カスタムクラス内で、設定を保持するクラスレベルのインスタンス変数を追加できます。例えば:

```ruby
class Types::BaseObject < GraphQL::Schema::Object
  # Call this method in an Object class to get or set the permission level:
  def self.required_permission(permission_level = nil)
    if permission_level.nil?
      # return the configured value
      @required_permission
    else
      @required_permission = permission_level
    end
  end
end

# Then, in concrete classes
class Dossier < BaseObject
  # The Dossier object type will have `.metadata[:required_permission] # => :admin`
  required_permission :admin
end

# Now, the type responds to that method:
Dossier.required_permission
# => :admin
```

これで、実行時に `type.required_permission` を呼ぶコードは設定した値を取得できます。

### field のカスタマイズ

fields は別の方法で生成されます。クラスを使う代わりに、fields は `GraphQL::Schema::Field`（またはそのサブクラス）のインスタンスとして生成されます。簡単に言うと、定義プロセスは次のように動作します:

```ruby
# This is what happens under the hood, roughly:
# In an object class:
field :name, String, null: false
# ...
# Leads to:
field_config = GraphQL::Schema::Field.new(name: :name, type: String, null: false)
```

したがって、このプロセスは次のようにカスタマイズできます:

- `GraphQL::Schema::Field` を拡張したカスタムクラスを作成する
- そのクラスで `#initialize` をオーバーライドする（インスタンスメソッド）
- カスタマイズした field を使いたい Object や Interface に `field_class` として登録する

例えば、`initialize` に新しい引数を受け取るカスタムクラスを作ることができます:

```ruby
class Types::BaseField < GraphQL::Schema::Field
  # Override #initialize to take a new argument:
  def initialize(*args, required_permission: nil, **kwargs, &block)
    @required_permission = required_permission
    # Pass on the default args:
    super(*args, **kwargs, &block)
  end

  attr_reader :required_permission
end
```

そして、使用する場所でその field クラスを `field_class(...)` として渡します:

```ruby
class Types::BaseObject < GraphQL::Schema::Object
  # Use this class for defining fields
  field_class BaseField
end

# And....
class Types::BaseInterface < GraphQL::Schema::Interface
  field_class BaseField
end

class Mutations::BaseMutation < GraphQL::Schema::RelayClassicMutation
  field_class BaseField
end
```

これで、これらの type 上の `GraphQL::Schema::Field` を作成する際に `BaseField.new(*args, &block)` が使われます。実行時に `field.required_permission` を呼ぶと設定した値が返ります。

### connection のカスタマイズ

Connection は Field と同様の方法でカスタマイズできます。

- `GraphQL::Types::Relay::BaseConnection` を拡張した新しいクラスを作成する
- `connection_type_class(MyCustomConnection)` を使って object/interface type に割り当てる

例えば、カスタム Connection を作ることができます:

```ruby
class Types::MyCustomConnection < GraphQL::Types::Relay::BaseConnection
  # BaseConnection has these nullable configurations
  # and the nodes field by default, but you can change
  # these options if you want
  edges_nullable(true)
  edge_nullable(true)
  node_nullable(true)
  has_nodes_field(true)

  field :total_count, Integer, null: false

  def total_count
    object.items.size
  end
end
```

そして、使用する場所で `connection_type_class(...)` としてそのクラスを渡します:

```ruby
module Types
  class Types::BaseObject < GraphQL::Schema::Object
    # Use this class for defining connections
    connection_type_class MyCustomConnection
  end
end
```

これで、`BaseObject` を拡張するすべての type クラスは、追加の field `totalCount` を備えた connection_type を持ちます。

### edge のカスタマイズ

Edge も Connection と同様の方法でカスタマイズできます。

- `GraphQL::Types::Relay::BaseEdge` を拡張した新しいクラスを作成する
- `edge_type_class(MyCustomEdge)` を使って object/interface type に割り当てる

### argument のカスタマイズ

Arguments も Fields と同様の方法でカスタマイズできます。

- `GraphQL::Schema::Argument` を拡張した新しいクラスを作成する
- カスタム argument クラスを base field クラス、base resolver クラス、base mutation クラスに `argument_class(MyArgClass)` で割り当てる

その後、カスタム argument クラス内で `#initialize(name, type, desc = nil, **kwargs)` を使って DSL からの入力を受け取ることができます。

### enum 値のカスタマイズ

Enum の値も Fields と同様の方法でカスタマイズできます。

- `GraphQL::Schema::EnumValue` を拡張した新しいクラスを作成する
- base `Enum` クラスに `enum_value_class(MyEnumValueClass)` で割り当てる

その後、カスタム enum クラス内で `#initialize(name, desc = nil, **kwargs)` を使って DSL からの入力を受け取ることができます。
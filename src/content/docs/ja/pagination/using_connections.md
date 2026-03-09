---
title: Connections の使い方
description: GraphQL-Ruby の組み込み connections によるページネーション
sidebar:
  order: 2
---
GraphQL-Ruby は、すぐに使えるいくつかの [connection パターン](pagination/connection_concepts) の実装を同梱しています。これらは Ruby の Array、Mongoid、Sequel、ActiveRecord をサポートします。

さらに、connections を使うと、クライアントの要求に関わらず返されるアイテム数を [`max_page_size`](#max-page-size) で制限したり、返されるアイテム数のデフォルトを [`default_page_size`](#default-page-size) で設定したりできます。

## Connection フィールドを作成する

`.connection_type` を使って、ある type のオブジェクトをページングするための connection type を生成します:

```ruby
field :items, Types::ItemType.connection_type, null: false
```

生成される戻り値の型は `ItemConnection` と呼ばれます。名前が `*Connection` で終わるため、`field(...)` は自動的に `connection: true` で設定されます。もし connection type の名前が `Connection` で終わらない場合は、その設定を自分で追加する必要があります:

```ruby
# here's a custom type whose name doesn't end in "Connection", so `connection: true` is required:
field :items, Types::ItemConnectionPage, null: false, connection: true
```

この field にはデフォルトでいくつかの argument が付与されます: `first`, `last`, `after`, `before`。

### デフォルトの connection 処理を無効にする

GraphQL-Ruby のデフォルトの connection 処理を無効にするには、field 定義に `connection: false` を追加します:

```diff
- field :items, Types::ItemType.connection_type, null: false
+ field :items, Types::ItemType.connection_type, null: false, connection: false
```

その後、必要な argument（`first`, `last`, `after`, `before` など）を追加し、resolver が設定した戻り値の型のフィールドを満たせるオブジェクトを返すようにしてください。

## コレクションを返す

connection フィールドでは、フィールドや resolver からコレクションオブジェクトを返すことができます:

```ruby
def items
  object.items # => eg, returns an ActiveRecord Relation
end
```

コレクションオブジェクト（Array、Mongoid relation、Sequel dataset、ActiveRecord relation）は、渡された引数に基づいて自動的にページングされます。カーソルはコレクション内のノードのオフセットに基づいて生成されます。

## カスタム Connections を作る

標準でサポートされていないものをページングしたい場合は、独自のページネーションラッパーを実装して GraphQL-Ruby に接続することができます。詳しくは [カスタム Connections](/pagination/custom_connections) を参照してください。

## 特殊なケース

同じクラスの他のインスタンスとは異なり、あるひとつのコレクションだけ特別な処理が必要になることがあります。そのような場合、resolver 内で手動で connection ラッパーを適用できます。例えば:

```ruby
def items
  # Get the ActiveRecord relation to paginate
  relation = object.items
  # Apply a custom wrapper
  Connections::ItemsConnection.new(relation)
end
```

このようにすることで、その「特定の」`relation` に対してカスタムコードで処理できます。

<a id="max-page-size"></a>
## 最大ページサイズ

`max_page_size` を適用すると、クライアントが何を要求してきても、返される・データベースから問い合わせられるアイテム数を制限できます。

- __スキーマ全体に対して__: スキーマ定義に追加できます:

```ruby
class MyAppSchema < GraphQL::Schema
  default_max_page_size 50
end
```

  実行時には、この値が（以下の上書きがない限り）すべての connection に適用されます。

- __特定の field に対して__: field 定義でキーワードとして追加します:

```ruby
field :items, Item.connection_type, null: false,
  max_page_size: 25
```

- __動的に__: カスタム connection ラッパーを適用する際に `max_page_size:` を渡せます:

```ruby
def items
  relation = object.items
  Connections::ItemsConnection.new(relation, max_page_size: 10)
end
```

`max_page_size` の設定を取り除きたい場合は、`nil` を渡してください。これにより、クライアントに対して上限のないコレクションを返せるようになります。

<a id="default-page-size"></a>
## 既定ページサイズ

`default_page_size` を適用すると、`first` や `last` が指定されていない場合の、返される・データベースから問い合わせられるアイテム数を制限できます。

- __スキーマ全体に対して__: スキーマ定義に追加できます:

```ruby
class MyAppSchema < GraphQL::Schema
  default_page_size 50
end
```

  実行時には、この値が（以下の上書きがない限り）すべての connection に適用されます。

- __特定の field に対して__: field 定義でキーワードとして追加します:

```ruby
field :items, Item.connection_type, null: false,
  default_page_size: 25
```

- __動的に__: カスタム connection ラッパーを適用する際に `default_page_size:` を渡せます:

```ruby
def items
  relation = object.items
  Connections::ItemsConnection.new(relation, default_page_size: 10)
end
```

もし `max_page_size` が設定されていて `default_page_size` がそれより大きい場合、`default_page_size` は `max_page_size` に合わせて制限されます。`default_page_size` と `max_page_size` の両方が `nil` に設定されている場合は、上限のないコレクションが返されます。
---
title: イントロスペクション
description: GraphQL には schema の構造を公開するイントロスペクションシステムがあります。
sidebar:
  order: 3
---
GraphQL schema には [組み込みのイントロスペクションシステム](https://graphql.org/learn/introspection/) があり、schema の構造を公開します。実際、このイントロスペクションシステムは GraphQL を使ってクエリ可能です。例えば:

```graphql
{
  __schema {
    queryType {
      name
    }
  }
}
# Returns:
# {
#   "data": {
#     "__schema": {
#       "queryType": {
#         "name": "Query"
#       }
#     }
#   }
# }
```

このシステムは [GraphiQL エディタ](https://github.com/graphql/graphiql) のような GraphQL ツールで利用されます。

デフォルトのイントロスペクションの要素は次のとおりです:

- `__schema` は schema のエントリポイント、types、directives などに関するデータを含むルートレベルの field です。
- `__type(name: String!)` は指定された `name` を持つ type に関するデータを返すルートレベルの field です（該当する type が存在する場合）。
- `__typename` は少し動作が異なります: 任意の選択（selection）に追加でき、クエリされているオブジェクトの type を返します。

`__typename` の例をいくつか示します:

```graphql
{
  user(id: "1") {
    handle
    __typename
  }
}
# Returns:
# {
#   "data": {
#     "user": {
#       "handle": "rmosolgo",
#       "__typename": "User"
#     }
#   }
# }
```

union や interface の場合、`__typename` は現在のオブジェクトのオブジェクト型（object type）を返します。例えば:

```graphql
{
  search(term: "puppies") {
    title
    __typename
  }
}
# Returns:
# {
#   "data": {
#     "search": [
#       {
#         "title": "Sound of Dogs Barking",
#         "__typename": "AudioClip",
#       },
#       {
#         "title": "Cute puppies playing with a stick",
#         "__typename": "VideoClip",
#       },
#       {
#         "title": "The names of my favorite pets",
#         "__typename": "TextSnippet"
#       },
#     ]
#   }
# }
```

イントロスペクションのカスタマイズ

カスタムのイントロスペクションタイプを使用できます。

```ruby
# create a module namespace for your custom types:
module Introspection
  # described below ...
end

class MySchema < GraphQL::Schema
  # ...
  # then pass the module as `introspection`
  introspection Introspection
end
```

ただし、既製のツールはカスタムのイントロスペクションフィールドをサポートしていない場合があります。既存のツールを修正するか、拡張機能を利用するために独自のツールを作成する必要があるかもしれません。

イントロスペクションのネームスペース

イントロスペクションのネームスペースには、いくつかの異なるカスタマイズを含めることができます:

- クラスベースの [オブジェクト定義](/type_definitions/objects)（組み込みのイントロスペクションタイプ（例: `__Schema` や `__Type`）を置き換えるもの）
- `EntryPoints`：イントロスペクションのエントリポイント（`__schema` や `__type(name:)` のような）を含むクラスベースの [オブジェクト定義](/type_definitions/objects)
- `DynamicFields`：動的でグローバルに利用可能なフィールド（`__typename` のような）を含むクラスベースの [オブジェクト定義](/type_definitions/objects)

カスタムイントロスペクションタイプ

`introspection` として渡される `module` には、組み込みのイントロスペクションタイプを置き換える次の名前のクラスを含めることができます:

カスタムクラス名 | GraphQL 型 | 組み込みクラス名
--|--|--
`SchemaType` | `__Schema` | [`GraphQL::Introspection::SchemaType`](https://graphql-ruby.org/api-doc/GraphQL::Introspection::SchemaType)
`TypeType` | `__Type` | [`GraphQL::Introspection::TypeType`](https://graphql-ruby.org/api-doc/GraphQL::Introspection::TypeType)
`DirectiveType` | `__Directive` | [`GraphQL::Introspection::DirectiveType`](https://graphql-ruby.org/api-doc/GraphQL::Introspection::DirectiveType)
`DirectiveLocationType` | `__DirectiveLocation` | [`GraphQL::Introspection::DirectiveLocationEnum`](https://graphql-ruby.org/api-doc/GraphQL::Introspection::DirectiveLocationEnum)
`EnumValueType` | `__EnumValue` | [`GraphQL::Introspection::EnumValueType`](https://graphql-ruby.org/api-doc/GraphQL::Introspection::EnumValueType)
`FieldType` | `__Field` | [`GraphQL::Introspection::FieldType`](https://graphql-ruby.org/api-doc/GraphQL::Introspection::FieldType)
`InputValueType` | `__InputValue` | [`GraphQL::Introspection::InputValueType`](https://graphql-ruby.org/api-doc/GraphQL::Introspection::InputValueType)
`TypeKindType` | `__TypeKind` | [`GraphQL::Introspection::TypeKindEnum`](https://graphql-ruby.org/api-doc/GraphQL::Introspection::TypeKindEnum)

クラスベース定義の名前は、置き換える型の名前と一致している必要があります。

組み込みタイプの拡張

上記の組み込みクラスは拡張できます:

```ruby
module Introspection
  class SchemaType < GraphQL::Introspection::SchemaType
    # ...
  end
end
```

クラス定義内では次のことが可能です:

- `field(...)` を呼び出して新しい fields を追加し、実装を提供する
- `field(...)` を呼び出して field の構造を再定義する
- メソッドを定義して新しい field の実装を提供する
- `description(...)` を呼び出して新しい説明を与える

イントロスペクションのエントリポイント

GraphQL 仕様では、イントロスペクションシステムへの 2 つのエントリポイントが定義されています:

- `__schema` は schema に関するデータを返します（型は `__Schema`）。
- `__type(name:)` は、名前で見つかった type に関するデータを返します（型は `__Type`）。

これらのフィールドを再実装したり、新しいフィールドを作成したりするには、イントロスペクションネームスペースにカスタムの `EntryPoints` クラスを作成します:

```ruby
module Introspection
  class EntryPoints < GraphQL::Introspection::EntryPoints
    # ...
  end
end
```

このクラスはオブジェクト型定義なので、ここで既存の fields をオーバーライドしたり、新しい fields を追加したりできます。これらはルートの `query` オブジェクトで利用可能になりますが、イントロスペクションでは無視されます（`__schema` や `__type` と同様です）。

動的フィールド

GraphQL 仕様では、任意の選択に追加できるフィールドとして `__typename` が記述されています。これは現在の GraphQL 型の名前を返します。

カスタムのフィールドを追加したり、`__typename` をオーバーライドしたりするには、カスタムの `DynamicFields` 定義を作成します:

```ruby
module Introspection
  class DynamicFields < GraphQL::Introspection::DynamicFields
    # ...
  end
end
```

ここで定義された任意のフィールドはどの選択でも利用可能になりますが、イントロスペクションでは無視されます（`__typename` と同様です）。

イントロスペクションの無効化

本番環境などでイントロスペクションのエントリポイント `__schema` と `__type` を無効にしたい場合は、ショートハンドメソッド `#disable_introspection_entry_points` を使えます:

```ruby
class MySchema < GraphQL::Schema
  disable_introspection_entry_points if Rails.env.production?
end
```

`disable_introspection_entry_points` は `__schema` と `__type` の両方のイントロスペクションエントリポイントを無効にします。個別に無効化したい場合は、ショートハンドメソッド `disable_schema_introspection_entry_point` および `disable_type_introspection_entry_point` を使うこともできます:

```ruby
class MySchema < GraphQL::Schema
  disable_schema_introspection_entry_point
  disable_type_introspection_entry_point
end
```
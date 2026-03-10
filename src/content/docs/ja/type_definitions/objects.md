---
title: オブジェクト
description: オブジェクトはデータを公開し、他のオブジェクトにリンクします
sidebar:
  order: 0
---
GraphQL object types は GraphQL API の基本です。各オブジェクトはデータを公開する _fields_ を持ち、名前で問い合わせできます。例えば、次のように `User` をクエリできます:

```ruby
user {
  handle
  email
}
```

そして次のような値が返ってきます:

```ruby
{
  "user" => {
    "handle" => "rmosolgo",
    "email" => nil,
  }
}
```

一般に、GraphQL object types はアプリケーション内のモデル（`User`、`Product`、`Comment` など）に対応します。場合によっては、object types は [GraphQL Schema 定義言語](https://graphql.org/learn/schema/#type-language)（SDL）を使って記述されます:

```ruby
type User {
  email: String
  handle: String!
  friends: [User!]!
}
```

これは `User` オブジェクトが 3 つの fields を持つことを意味します:

- `email` は `String` もしくは `nil` を返す可能性があります。
- `handle` は `String` を返し、決して `nil` になりません（`!` はその field が決して `nil` を返さないことを意味します）。
- `friends` は他の `User` のリストを返します（`[...]` はその field が値のリストを返すことを意味します。`User!` はリストが `User` オブジェクトを含み、`nil` を含まないことを意味します）。

同じオブジェクトは Ruby を使って次のように定義できます:

```ruby
class Types::User < GraphQL::Schema::Object
  field :email, String
  field :handle, String, null: false
  field :friends, [User], null: false
end
```

このガイドの残りでは、Ruby で GraphQL object types を定義する方法を説明します。GraphQL object types 全般について詳しくは、[GraphQL ドキュメント](https://graphql.org/learn/schema/#object-types-and-fields) を参照してください。

## オブジェクトクラス

[`GraphQL::Schema::Object`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Object) を継承するクラスは [Object types（オブジェクトタイプ）](https://graphql.org/learn/schema/#object-types-and-fields) を記述し、その振る舞いをカスタマイズします。

Object fields は `field(...)` クラスメソッドで作成できます。[下で詳しく説明します](#fields)。

field と argument の名前は慣例としてスネークケースにしてください。内部の GraphQL type では camelCase に変換され、schema 自体でも camelCase になります。

```ruby
# first, somewhere, a base class:
class Types::BaseObject < GraphQL::Schema::Object
end

# then...
class Types::TodoList < Types::BaseObject
  comment "Comment of the TodoList type"
  description "A list of items which may be completed"

  field :name, String, "The unique name of this list", null: false
  field :is_completed, String, "Completed status depending on all tasks being done.", null: false
  # Related Object:
  field :owner, Types::User, "The creator of this list", null: false
  # List field:
  field :viewers, [Types::User], "Users who can see this list", null: false
  # Connection:
  field :items, Types::TodoItem.connection_type, "Tasks on this list", null: false do
    argument :status, TodoStatus, "Restrict items to this status", required: false
  end
end
```

## Fields（フィールド）

Object fields はそのオブジェクトのデータを公開するか、別のオブジェクトへの接続を提供します。`field(...)` クラスメソッドで object types に fields を追加できます。

詳細は [Fields ガイド](/fields/introduction) を参照してください。

## interfaces の実装

オブジェクトが interfaces を実装する場合は、`implements` で追加できます。例:

```ruby
# This object implements some interfaces:
implements GraphQL::Types::Relay::Node
implements Types::UserAssignableType
```

オブジェクトが `implements` で interfaces を実装すると、次のことが起こります:

- その interface から GraphQL field 定義を継承します
- その module をオブジェクト定義に含めます

interfaces について詳しくは [Interfaces ガイド](/type_definitions/interfaces) を参照してください。
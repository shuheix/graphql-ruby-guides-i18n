---
title: Input Objects
description: Input objects はフィールドの argument として使用できるキーと値のペアの集合です。
sidebar:
  order: 3
---
Input object types は GraphQL の操作に対する複雑な入力です。mutations や検索用のフィールドのように、構造化された大量の入力を必要とするフィールドに適しています。GraphQL リクエストでは例えば次のようになります:

```ruby
mutation {
  createPost(attributes: { title: "Hello World", fullText: "This is my first post", categories: [GENERAL] }) {
    #                    ^ Here is the input object ..................................................... ^
  }
}
```

Ruby の `Hash` のように、input object はキーと値で構成されます。ただし Hash と異なり、そのキーと値の型は GraphQL システムの一部として静的に定義する必要があります。例えば、以下は [GraphQL Schema Definition Language](https://graphql.org/learn/schema/#input-object-types) (SDL) で表現した input object です:

```ruby
input PostAttributes {
  title: String!
  fullText: String!
  categories: [PostCategory!]
}
```

この input object には 3 つの可能なキーがあります:

- `title` は必須（`!` で示され）、`String` でなければなりません
- `fullText` も必須の `String` です
- `categories` は任意（`!` が付いていない）で、存在する場合は `PostCategory` のリストでなければなりません

## Input object types の定義

Input object types は [`GraphQL::Schema::InputObject`](https://graphql-ruby.org/api-doc/GraphQL::Schema::InputObject) を継承し、`argument(...)` メソッドでキーと値のペアを定義します。例えば:

```ruby
# app/graphql/types/base_input_object.rb
# Add a base class
class Types::BaseInputObject < GraphQL::Schema::InputObject
end

class Types::PostAttributes < Types::BaseInputObject
  description "Attributes for creating or updating a blog post"
  argument :title, String, "Header for the post"
  argument :full_text, String, "Full body of the post"
  argument :categories, [Types::PostCategory], required: false
end
```

`argument(...)` メソッドの詳細は、Objects ガイドの [argument セクション](/fields/arguments.html) を参照してください。

## Input objects の使い方

Input objects はフィールドメソッドに、その定義クラスのインスタンスとして渡されます。したがって、フィールドメソッド内ではオブジェクトの任意のキーに対して次の方法でアクセスできます:

- 名前に対応するメソッド（underscore された名前）を呼ぶ
- 互換性のために、argument のキャメルケース名で `#[]` を呼ぶ

```ruby
class Types::MutationType < GraphQL::Schema::Object
  # This field takes an argument called `attributes`
  # which will be an instance of `PostAttributes`
  field :create_post, Types::Post, null: false do
    argument :attributes, Types::PostAttributes
  end

  def create_post(attributes:)
    puts attributes.class.name
    # => "Types::PostAttributes"
    # Access a value by method (underscore-cased):
    puts attributes.full_text
    # => "This is my first post"
    # Or by hash-style lookup (camel-cased, for compatibility):
    puts attributes[:fullText]
    # => "This is my first post"
  end
end
```

## Input objects のカスタマイズ

Input objects に使われる `GraphQL::Schema::Argument` クラスをカスタマイズできます:

```ruby
class Types::BaseArgument < GraphQL::Schema::Argument
  # your customization here ...
end


class Types::BaseInputObject < GraphQL::Schema::InputObject
  # Hook up the customized argument class
  argument_class(Types::BaseArgument)
end
```

また、input object クラスにメソッドを追加したりオーバーライドしたりしてカスタマイズすることもできます。デフォルトで以下の 2 つのインスタンス変数を持っています:

- `@arguments`: [`GraphQL::Execution::Interpreter::Arguments`](https://graphql-ruby.org/api-doc/GraphQL::Execution::Interpreter::Arguments) のインスタンス
- `@context`: 現在の [`GraphQL::Query::Context`](https://graphql-ruby.org/api-doc/GraphQL::Query::Context)

クラスに定義した追加のメソッドは、上の例のようにフィールド解決で利用できます。

## 他の Ruby オブジェクトへの変換

Input objects はアプリケーションコードに渡される前に自動的に他の Ruby 型へ変換できます。これによりスキーマで `Range` を簡単に使えるようになります:

```ruby
class Types::DateRangeInput < Types::BaseInputObject
  description "Range of dates"
  argument :min, Types::Date, "Minimum value of the range"
  argument :max, Types::Date, "Maximum value of the range"

  def prepare
    min..max
  end
end

class Types::CalendarType < Types::BaseObject
  field :appointments, [Types::Appointment], "Appointments on your calendar", null: false do
    argument :during, Types::DateRangeInput, "Only show appointments within this range"
  end

  def appointments(during:)
    # during will be an instance of Range
    object.appointments.select { |appointment| during.cover?(appointment.date) }
  end
end
```

## `@oneOf`

`one_of` を使うと、ちょうど 1 つのフィールドのみが提供されることを要求する input object を作成できます:

```ruby
class FindUserInput < Types::BaseInput
  one_of
  # Either `{ id: ... }` or `{ username: ... }` may be given,
  # but not both -- and one of them _must_ be given.
  argument :id, ID, required: false
  argument :username, String, required: false
end
```

`one_of` を指定した input object は、与えられた引数がちょうど1つであること、かつ与えられた引数の値が `nil` でないことを要求します。`one_of` を使う場合、各引数は個別には必須ではないため `required: false` にする必要があります。

`one_of` を使用すると、スキーマ出力では `input ... @oneOf` と表示され、次のように問い合わせることで確認できます: `{ __type(name: $typename) { isOneOf } }`。

この挙動は 2025 年 9 月の GraphQL 仕様に採用されました。
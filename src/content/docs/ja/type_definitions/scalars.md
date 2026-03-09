---
title: Scalars
description: Scalarsは整数や文字列のような「単純な」データ型です
sidebar:
  order: 1
---
ScalarsはGraphQLにおける「葉」値です。いくつかの組み込みscalarsがあり、カスタムscalarsを定義することもできます。([Enums](/type_definitions/enums)も葉の値です。) 組み込みscalarsは次のとおりです:

- `String`：JSONやRubyの文字列のようなもの
- `Int`：JSONやRubyの整数のようなもの
- `Float`：JSONやRubyの浮動小数点数のようなもの
- `Boolean`：JSONやRubyの真偽値（`true` または `false`）
- `ID`：ユニークなオブジェクト識別子を表現するための特殊な `String`
- `ISO8601DateTime`：ISO 8601でエンコードされた日時
- `ISO8601Date`：ISO 8601でエンコードされた日付
- `ISO8601Duration`：ISO 8601でエンコードされた期間。⚠ これは `ActiveSupport::Duration` が読み込まれていることを必要とし、定義されていない状態で `.coerce_*` メソッドが呼ばれると [`GraphQL::Error`](https://graphql-ruby.org/api-doc/GraphQL::Error) を発生させます。
- `JSON`、⚠ 任意のJSON（Rubyのハッシュ、配列、文字列、整数、浮動小数点、真偽値、nil）を返します。注意: この型を使用すると、GraphQLの型安全性が完全に失われます。代わりにデータのためのobject typesを構築することを検討してください。
- `BigInt`：32ビット整数のサイズを超える可能性のある数値

フィールドは名前で組み込みscalarsを参照して返すことができます:

```ruby
# String field:
field :name, String,
# Integer field:
field :top_score, Int, null: false
# or:
field :top_score, Integer, null: false
# Float field
field :avg_points_per_game, Float, null: false
# Boolean field
field :is_top_ranked, Boolean, null: false
# ID field
field :id, ID, null: false
# ISO8601DateTime field
field :created_at, GraphQL::Types::ISO8601DateTime, null: false
# ISO8601Date field
field :birthday, GraphQL::Types::ISO8601Date, null: false
# ISO8601Duration field
field :age, GraphQL::Types::ISO8601Duration, null: false
# JSON field ⚠
field :parameters, GraphQL::Types::JSON, null: false
# BigInt field
field :sales, GraphQL::Types::BigInt, null: false
```

カスタムscalars（下記参照）も名前で使用できます:

```ruby
# `homepage: Url`
field :homepage, Types::Url
```

[スキーマ定義言語 (SDL)](https://graphql.org/learn/schema/#scalar-types) では、scalarsは単に名前だけで定義されます:

```ruby
scalar DateTime
```

## カスタム Scalars

独自のscalarsは [`GraphQL::Schema::Scalar`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Scalar) を継承して実装できます。例えば:

```ruby
# app/graphql/types/base_scalar.rb
# Make a base class:
class Types::BaseScalar < GraphQL::Schema::Scalar
end

# app/graphql/types/url.rb
class Types::Url < Types::BaseScalar
  comment "TODO comment of the scalar"
  description "A valid URL, transported as a string"

  def self.coerce_input(input_value, context)
    # Parse the incoming object into a `URI`
    url = URI.parse(input_value)
    if url.is_a?(URI::HTTP) || url.is_a?(URI::HTTPS)
      # It's valid, return the URI object
      url
    else
      raise GraphQL::CoercionError, "#{input_value.inspect} is not a valid URL"
    end
  end

  def self.coerce_result(ruby_value, context)
    # It's transported as a string, so stringify it
    ruby_value.to_s
  end
end
```

クラスは次の2つのクラスメソッドを定義する必要があります:

- `self.coerce_input` はGraphQLの入力を受け取り、Rubyの値に変換します
- `self.coerce_result` はフィールドの返り値を受け取り、GraphQLレスポンスのJSON向けに準備します

入力データが不正な場合、メソッドは [`GraphQL::CoercionError`](https://graphql-ruby.org/api-doc/GraphQL::CoercionError) を発生させることができ、これはクライアントに `"errors"` キーで返されます。

Scalarクラスはインスタンス化されることはなく、実行時には `.coerce_*` メソッドのみが呼ばれます。
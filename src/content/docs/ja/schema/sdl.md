---
title: GraphQL Schema Definition Language を Ruby schema にパースする
description: 文字列または .graphql ファイルから schema を定義する
sidebar:
  order: 7
---
GraphQL-Ruby には、GraphQL Schema Definition Language (SDL) から実行可能な schema を構築する方法が含まれています。[`GraphQL::Schema.from_definition`](https://graphql-ruby.org/api-doc/GraphQL::Schema.from_definition) は、ファイル名または GraphQL SDL を含む文字列に基づいて schema クラスを返します。例えば:

```ruby
# From a file:
MySchema = GraphQL::Schema.from_definition("path/to/schema.graphql")
# Or, from a string:
MySchema = GraphQL::Schema.from_definition(<<~GRAPHQL)
  type Query {
    # ...
  }
  # ...
GRAPHQL
```

SDL からの定義は、プレーンな Ruby コードで定義したものと同様に Ruby クラスへ変換されます。

## 実行

生成された schema に対しては、`default_resolve:` を使って実行時の振る舞いを提供できます。`default_resolve:` は次の 2 種類の値を受け取ります。

- 実装オブジェクト (Implementation Object): 実行時に使われる複数のメソッドを実装したオブジェクト
- 実装ハッシュ (Implementation Hash): 実行のための proc を提供するキーとネストされたハッシュ

### 実装オブジェクト

実行時に使われるいくつかのメソッドを実装したオブジェクトを渡すことで、SDL からロードした schema の実行振る舞いを定義できます:

```ruby
class SchemaImplementation
  # see below for methods
end

# Pass the object as `default_resolve:`
MySchema = GraphQL::Schema.from_definition(
  "path/to/schema.graphql",
  default_resolve: SchemaImplementation.new
)
```

`default_resolve:` に渡すオブジェクトは次を実装していても構いません:

- `#call(type, field, obj, args, ctx)` — fields を解決するため
- `#resolve_type(abstract_type, obj, ctx)` — `abstract_type` の可能な object type のいずれかとして `obj` を解決するため
- `#coerce_input(type, value, ctx)` — scalar 入力をコアスするため
- `#coerce_result(type, value, ctx)` — scalar 戻り値をコアスするため

### 実装ハッシュ

あるいは、呼び出し可能な振る舞いを含む Hash を渡すこともできます。例:

```ruby
schema_implementation = {
  # ... see below for hash structure
}

# Pass the hash as `default_resolve:`
MySchema = GraphQL::Schema.from_definition(
  "path/to/schema.graphql",
  default_resolve: schema_implementation
)
```

ハッシュは次を含むことができます:

- 各 object type 名ごとのキー。値は `{ field_name => ->(obj, args, ctx) { ... } }` のようなサブハッシュで、object の fields を解決するための proc を提供します
- 各 scalar type 名ごとのキー。値は `"coerce_result"` と `"coerce_input"` というキーを持つサブハッシュで、それぞれ `->(value, ctx) { ... }` を指し、実行時の scalar 値の処理を行います
- `"resolve_type"` キーに対しては `->(abstract_type, object, ctx) { ... }` のような callable を指定できます。これは `object` を `abstract_type` の可能な type のいずれかに解決するために使われます

## プラグイン

[`GraphQL::Schema.from_definition`](https://graphql-ruby.org/api-doc/GraphQL::Schema.from_definition) は `using:` 引数を受け取り、`plugin => args` のペアのマップとして渡すことができます。例えば:

```ruby
MySchema = GraphQL::Schema.from_definition("path/to/schema.graphql", using: {
  GraphQL::Pro::PusherSubscriptions => { redis: $redis },
  GraphQL::Pro::OperationStore => nil, # no options here
})
```

## directive（ディレクティブ）

GraphQL-Ruby は SDL の directive に対する特別な処理を持ちませんが、アプリ側でカスタムの振る舞いを構築できます。スキーマの一部に directive が含まれている場合は、`.ast_node.directives` を使ってアクセスできます。例えば:

```ruby
schema = GraphQL::Schema.from_definition <<-GRAPHQL
type Query @flagged {
  secret: Boolean @privacy(secret: true)
}
GRAPHQL

pp schema.query.ast_node.directives.map(&:to_query_string)
# => ["@flagged"]
pp schema.get_field("Query", "secret").ast_node.directives.map(&:to_query_string)
# => ["@privacy(secret: true)"]
```

利用可能なメソッドについては [`GraphQL::Language::Nodes::Directive`](https://graphql-ruby.org/api-doc/GraphQL::Language::Nodes::Directive) を参照してください。
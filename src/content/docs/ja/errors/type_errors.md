---
title: Type エラー
description: Type エラーの処理
sidebar:
  order: 3
---
GraphQL仕様では、クエリを実行する際にいくつかの前提が成り立つことが必須です。しかし、コードによってはその前提が破られ、type エラーが発生する可能性があります。

GraphQL-Ruby でカスタマイズできる type エラーは次の2つです:

- `null: false` を持つ field が `nil` を返した場合
- field が union または interface として値を返したが、その値をその union または interface のメンバーに解決できなかった場合

これらの場合の振る舞いは、[`Schema.type_error`](https://graphql-ruby.org/api-doc/Schema.type_error) hook を定義して指定できます:

```ruby
class MySchema < GraphQL::Schema
  def self.type_error(err, query_ctx)
    # Handle a failed runtime type coercion
  end
end
```

この hook は [`GraphQL::UnresolvedTypeError`](https://graphql-ruby.org/api-doc/GraphQL::UnresolvedTypeError) または [`GraphQL::InvalidNullError`](https://graphql-ruby.org/api-doc/GraphQL::InvalidNullError) のインスタンスと、クエリコンテキスト（[`GraphQL::Query::Context`](https://graphql-ruby.org/api-doc/GraphQL::Query::Context)）を引数に呼び出されます。

hook を指定しない場合のデフォルトの動作は次の通りです:

- 予期しない `nil` はレスポンスの "errors" キーにエラーを追加します
- 解決できない Union / Interface type は [`GraphQL::UnresolvedTypeError`](https://graphql-ruby.org/api-doc/GraphQL::UnresolvedTypeError) を発生させます

type 解決に失敗したオブジェクトは `nil` として扱われます。
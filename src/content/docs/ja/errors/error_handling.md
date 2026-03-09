---
title: エラー処理
description: field resolvers からのアプリケーションエラーを救出する
sidebar:
  order: 3
---
あなたの schema を設定して、field 解決中のアプリケーションエラーを救出することができます。batch loading 中のエラーも救出されます。

[`@exAspArk`](https://github.com/exaspark) に感謝します（この挙動に着想を与えた [`graphql-errors`](https://github.com/exAspArk/graphql-errors) gem）と、こんな実装を[提案した](https://github.com/rmosolgo/graphql-ruby/issues/2139#issuecomment-524913594) [`@thiago-sydow`](https://github.com/thiago-sydow)。

## エラーハンドラーの追加

ハンドラーは schema の `rescue_from` 設定で追加します:

```ruby
class MySchema < GraphQL::Schema
  # ...

  rescue_from(ActiveRecord::RecordNotFound) do |err, obj, args, ctx, field|
    # Raise a graphql-friendly error with a custom message
    raise GraphQL::ExecutionError, "#{field.type.unwrap.graphql_name} not found"
  end

  rescue_from(SearchIndex::UnavailableError) do |err, obj, args, ctx, field|
    # Log the error
    Bugsnag.notify(err)
    # replace it with nil
    nil
  end
end
```

ハンドラーは次の引数で呼び出されます:

- __`err`__ はフィールド実行中に発生し救出されたエラーです
- __`obj`__ はそのフィールドが解決されていたオブジェクトです
- __`args`__ はリゾルバに渡された引数の Hash です
- __`ctx`__ はクエリコンテキストです
- __`field`__ はエラーが救出されたフィールドの [`GraphQL::Schema::Field`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Field) インスタンスです

ハンドラー内では次のことができます:

- ユーザーに返すために、GraphQL に適した [`GraphQL::ExecutionError`](https://graphql-ruby.org/api-doc/GraphQL::ExecutionError) を raise する
- 与えられた `err` を再度 raise してクエリをクラッシュさせ、実行を停止する（エラーはコントローラーなどアプリケーション側に伝播します）
- 必要に応じてエラーからメトリクスを報告する
- （別のエラーを raise しない場合）エラー時に使用する新しい値を返す
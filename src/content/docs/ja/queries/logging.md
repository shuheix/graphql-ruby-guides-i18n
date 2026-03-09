---
title: ログ出力
description: GraphQL-Ruby の開発用出力
sidebar:
  order: 12
---
実行時、GraphQL-Ruby は [`GraphQL::Query#logger`](https://graphql-ruby.org/api-doc/GraphQL::Query#logger) を使ってデバッグ情報を出力します。デフォルトでは `Rails.logger` が使われます。出力を確認するには、`config.log_level = :debug` を設定してください。（この情報は本番ログ向けではありません。）

カスタムのロガーは [`GraphQL::Schema.default_logger`](https://graphql-ruby.org/api-doc/GraphQL::Schema.default_logger) で設定できます。例えば:

```ruby
class MySchema < GraphQL::Schema
  # This logger will be used by queries during execution:
  default_logger MyCustomLogger.new
end
```

実行中にロガーを渡すには、`context[:logger]` を指定することもできます。
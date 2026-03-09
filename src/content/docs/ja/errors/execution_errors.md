---
title: トップレベルの "errors"
description: トップレベルの "errors" 配列とその使い方
sidebar:
  order: 1
---
GraphQL の仕様はレスポンスにトップレベルの「errors」キーを含めることを許可しており、実行中に何が問題だったかに関する情報を格納できます。詳しくは [GraphQL specification はレスポンスにトップレベルの「errors」キーを許可しています](https://graphql.github.io/graphql-spec/June2018/#sec-Errors)。例えば:

```ruby
{
  "errors" => [ ... ]
}
```

部分的に成功した場合、レスポンスは `"data"` と `"errors"` の両方を含むことがあります:

```ruby
{
  "data" => { ... } # parts of the query that ran successfully
  "errors" => [ ... ] # errors that prevented some parts of the query from running
}
```

## トップレベルの「errors」を使う場合

一般的に、トップレベルの errors は、開発者にシステムに何らかの問題が発生したことを通知すべき例外的な状況にのみ使用するべきです。

例えば、GraphQL 仕様では非 null の field が `nil` を返した場合、`"errors"` キーにエラーを追加するべきだとしています。この種のエラーはクライアント側で回復可能ではありません。代わりに、このケースを処理するためにサーバ側で何かを修正する必要があります。

クライアントに回復可能な問題を通知したい場合は、スキーマの一部としてエラーメッセージを返すことを検討してください。例えば [mutation のエラー](/mutations/mutation_errors) のように実装します。

## 配列にエラーを追加する方法

GraphQL-Ruby では、この配列にエントリを追加するには `GraphQL::ExecutionError`（またはそのサブクラス）を発生させます。例えば:

```ruby
raise GraphQL::ExecutionError, "Can't continue with this query"
```

このエラーが発生すると、その `message` が `"errors"` キーに追加され、GraphQL-Ruby が自動的に `line`、`column`、`path` を付加します。したがって、上のエラーは次のようになるかもしれません:

```ruby
{
  "errors" => [
    {
      "message" => "Can't continue with this query",
      "locations" => [
        {
          "line" => 2,
          "column" => 10,
        }
      ],
      "path" => ["user", "login"],
    }
  ]
}
```

## エラー JSON のカスタマイズ

デフォルトのエラー JSON には `"message"`、`"locations"`、`"path"` が含まれます。GraphQL 仕様の[今後のバージョン](https://spec.graphql.org/draft/#example-fce18)では、カスタムデータをエラー JSON の `"extensions"` キーに入れることを推奨しています。

これをカスタマイズするには、次の 2 通りの方法があります:

- エラーを発生させるときに `extensions:` を渡す。例えば:
  ```ruby
  raise GraphQL::ExecutionError.new("Something went wrong", extensions: { "code" => "BROKEN" })
  ```
  この場合、エラー JSON に `"extensions" => { "code" => "BROKEN" }` が追加されます。

- `GraphQL::ExecutionError` のサブクラスで `#to_h` をオーバーライドする。例えば:
  ```ruby
  class ServiceUnavailableError < GraphQL::ExecutionError
    def to_h
      super.merge({ "extensions" => {"code" => "SERVICE_UNAVAILABLE"} })
    end
  end
  ```
  これにより、エラー JSON に `"extensions" => { "code" => "SERVICE_UNAVAILABLE" }` が追加されます。
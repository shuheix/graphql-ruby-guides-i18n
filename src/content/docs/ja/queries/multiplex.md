---
title: マルチプレックス
description: 複数のクエリを同時に実行する
sidebar:
  order: 10
---
いくつかのクライアントはサーバに対して複数のクエリを同時に送信する場合があります（例: [Apollo Client のクエリバッチング](https://www.apollographql.com/docs/react/api/link/apollo-link-batch-http/)）。これらは [`Schema.multiplex`](https://graphql-ruby.org/api-doc/Schema.multiplex) を使って並行して実行できます。

マルチプレックスの実行は、それぞれ独自のコンテキスト、analyzers、および instrumentation を持ちます。

注: 実装の詳細として、すべてのクエリは multiplex の内部で実行されます。つまり、単独のクエリも「1 件のマルチプレックス」として実行されるため、`MySchema.execute(...)` で実行される単独クエリにもインストルメンテーションやマルチプレックスのアナライザ、トレーサーが適用されます。

## 同時実行

クエリを並行実行するには、クエリ文字列に対して `query:` を使ってクエリオプションの配列を作成します。例:

```ruby
# Prepare the context for each query:
context = {
  current_user: current_user,
}

# Prepare the query options:
queries = [
  {
   query: "query Query1 { someField }",
   variables: {},
   operation_name: 'Query1',
   context: context,
 },
 {
   query: "query Query2 ($num: Int){ plusOne(num: $num) }",
   variables: { num: 3 },
   operation_name: 'Query2',
   context: context,
 }
]
```

その後、`Schema.multiplex` に渡します:

```ruby
results = MySchema.multiplex(queries)
```

`results` には `queries` の各クエリの結果が含まれます。注: 結果は常にそれぞれのリクエストが送信された順序と同じ順序になります。

## Apollo のクエリバッチング

Apollo はバッチ処理が有効な場合、クエリの配列としてバッチを送信します。Rails の ActionDispatch はリクエストを解析して結果を `params` 変数の `_json` フィールドに入れます。スキーマがバッチと非バッチの両方を処理できるようにする必要があります。以下は Apollo のバッチに対応するように書き換えたデフォルトの GraphqlController の例です:

```ruby
def execute
  context = {}

  # Apollo sends the queries in an array when batching is enabled. The data ends up in the _json field of the params variable.
  # see the Apollo Documentation about query batching: https://www.apollographql.com/docs/react/api/link/apollo-link-batch-http/
  result = if params[:_json]
    queries = params[:_json].map do |param|
      {
        query: param[:query],
        operation_name: param[:operationName],
        variables: ensure_hash(param[:variables]),
        context: context
      }
    end
    MySchema.multiplex(queries)
  else
    MySchema.execute(
      params[:query],
      operation_name: params[:operationName],
      variables: ensure_hash(params[:variables]),
      context: context
    )
  end

  render json: result, root: false
end
```

## 検証とエラー処理

各クエリは独立して検証および[解析](/queries/ast_analysis)されます。`results` 配列には成功した結果と失敗した結果が混在する可能性があります。

## マルチプレックスレベルのコンテキスト

`context:` ハッシュを渡すことで、[`Execution::Multiplex#context`](https://graphql-ruby.org/api-doc/Execution::Multiplex#context) に値を追加できます:

```ruby
MySchema.multiplex(queries, context: { current_user: current_user })
```

これはインストルメンテーションから `multiplex.context[:current_user]` として利用できます（下記参照）。

## マルチプレックスレベルの解析

マルチプレックス内のすべてのクエリを解析するには、マルチプレックスアナライザを追加します。例えば:

```ruby
class MySchema < GraphQL::Schema
  # ...
  multiplex_analyzer(MyAnalyzer)
end
```

API は [query analyzers](/queries/ast_analysis#analyzing-multiplexes) と同じです。

マルチプレックスアナライザは、マルチプレックス全体の実行を停止するために [`AnalysisError`](https://graphql-ruby.org/api-doc/AnalysisError) を返すことがあります。

## マルチプレックスのトレース

[トレースモジュール](/queries/tracing) を使って、各マルチプレックス実行にフックを追加できます。

トレースモジュールは `def execute_multiplex(multiplex:)` を実装し、`yield` してマルチプレックスの実行を許可することができます。利用可能なメソッドについては [`Execution::Multiplex`](https://graphql-ruby.org/api-doc/Execution::Multiplex) を参照してください。

例:

```ruby
# Count how many queries are in the multiplex run:
module MultiplexCounter
  def execute_multiplex(multiplex:)
    Rails.logger.info("Multiplex size: #{multiplex.queries.length}")
    yield
  end
end

# ...

class MySchema < GraphQL::Schema
  # ...
  trace_with(MultiplexCounter )
end
```

これで、各実行ごとに `MultiplexCounter#execute_multiplex` が呼ばれ、各マルチプレックスのサイズがログに出力されます。
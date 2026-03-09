---
title: サーバーのセットアップ
description: スキーマとサーバーを @defer 用に設定する
sidebar:
  order: 1
pro: true
---
`@defer` をクエリで使う前に、次を行ってください:

- `graphql` と `graphql-pro` gem を更新する
- `@defer` をあなたの GraphQL schema に追加する
- ストリーミングレスポンスを送信するように HTTP ハンドラ（例: Rails のコントローラ）を更新する
- 必要に応じて、GraphQL-Batch と連携するよう `@defer` をカスタマイズする

また、[Rails と Apollo-Client のフルデモ](https://github.com/rmosolgo/graphql_defer_example)も参照できます。

## gem の更新

GraphQL-Ruby 1.9+ と GraphQL-Pro 1.10+ が必要です:

```ruby
gem "graphql", "~>1.9"
gem "graphql-pro", "~>1.10"
```

そしてインストールします:

```
$ bundle update graphql graphql-pro
```

## schema に `@defer` を追加する

次に、`GraphQL::Pro::Defer` を schema の plugin として追加します:

```ruby
class MySchema < GraphQL::Schema
  use GraphQL::Pro::Defer
end
```

これにより次のことが行われます:

- `@defer` という [カスタム directive](/type_definitions/directives) が追加されます
- クエリに対して instrumentation が追加され、deferred な処理を追跡して後で実行できるようになります

## ストリーミングレスポンスの送信

多くの web フレームワークはストリーミングレスポンスをサポートしています。例えば:

- Rails は [ActionController::Live](https://api.rubyonrails.org/classes/ActionController/Live.html) を持っています
- Sinatra は [Sinatra::Streaming](http://sinatrarb.com/contrib/streaming.html) を持っています
- Hanami::Controller は [レスポンスのストリーミング](https://github.com/hanami/controller#streamed-responses) を行えます

以下では、GraphQL の deferred patch をストリーミングレスポンス API と統合する方法を示します。

特定の web フレームワークでのサポート状況を調査したい場合は、{% open_an_issue "Server support for @defer with ..." %} を開くか、`support@graphql.pro` にメールしてください。

### defer の確認

クエリに `@defer` 指定された field が含まれている場合、`context[:defer]` をチェックできます:

```ruby
if context[:defer]
  # some fields were `@defer`ed
else
  # normal GraphQL, no `@defer`
end
```

### defer の処理

defer を扱うには、`context[:defer]` を列挙できます。例えば:

```ruby
context[:defer].each do |deferral|
  # do something with the `deferral`, eg
  # stream_to_client(deferral.to_h)
end
```

最初の結果も deferrals に含まれているため、patch と同様に扱えます。

各 deferred patch はレスポンスを作るためのいくつかのメソッドを持ちます:

- `.to_h` は `path:`, `data:`, および/または `errors:` を含むハッシュを返します。（ルート結果には `path:` はありません。）
- `.to_http_multipart(incremental: true)` は Apollo client の `@defer` サポートで動作する文字列を返します。（来るべき仕様に合わせる場合は `incremental: true` を使って patch をフォーマットします。）
- `.path` はレスポンス内でこの patch のパスを返します
- `.data` は patch の成功した解決結果を返します
- `.errors` はエラーがあれば配列で返します

deferral に対して `.data` または `.errors` を呼ぶと、patch が完了するまで GraphQL の実行が再開されます。

### 例: Rails と Apollo Client

この例では、Rails のコントローラが Apollo Client のサポートする形式で HTTP Multipart patch をクライアントにストリーミングします。

```ruby
class GraphqlController < ApplicationController
  # Support `response.stream` below:
  include ActionController::Live

  def execute
    # ...
    result = MySchema.execute(query, variables: variables, context: context, operation_name: operation_name)

    # Check if this is a deferred query:
    if (deferred = result.context[:defer])
      # Required for Rack 2.2+, see https://github.com/rack/rack/issues/1619
      response.headers['Last-Modified'] = Time.now.httpdate
      # Use built-in `stream_http_multipart` with Apollo-Client & ActionController::Live
      deferred.stream_http_multipart(response, incremental: true)
    else
      # Return a plain, non-deferred result
      render json: result
    end
  ensure
    # Always make sure to close the stream
    response.stream.close
  end
end
```

また、[Rails と Apollo-Client のフルデモ](https://github.com/rmosolgo/graphql_defer_example)も参照できます。

## GraphQL-Batch を使う場合

`GraphQL-Batch` は GraphQL-Ruby の実行をラップするサードパーティのデータローディングライブラリです。Deferred 解決は通常の実行フローの外で発生するため、GraphQL-Batch と連携させるには `GraphQL::Pro::Defer` を少しカスタマイズする必要があります。また、GraphQL-Pro の `v1.24.6` 以降が必要です。以下はカスタムの `Defer` 実装の例です:

```ruby
# app/graphql/directives/defer.rb
module Directives
  # Modify the library's `@defer` implementation to work with GraphQL-Batch
  class Defer < GraphQL::Pro::Defer
    def self.resolve(obj, arguments, context, &block)
      # While the query is running, store the batch executor to re-use later
      context[:graphql_batch_executor] ||= GraphQL::Batch::Executor.current
      super
    end

    class Deferral < GraphQL::Pro::Defer::Deferral
      def resolve
        # Before calling the deferred execution,
        # set GraphQL-Batch back up:
        prev_executor = GraphQL::Batch::Executor.current
        GraphQL::Batch::Executor.current ||= @context[:graphql_batch_executor]
        super
      ensure
        # Clean up afterward:
        GraphQL::Batch::Executor.current = prev_executor
      end
    end
  end
end
```

そして schema を更新してカスタムの defer 実装を使います:

```ruby
# Use our GraphQL-Batch-compatible defer:
use Directives::Defer
```

## 次のステップ

`@defer` のクライアントでの使用法については [client usage](/defer/usage) を参照してください。
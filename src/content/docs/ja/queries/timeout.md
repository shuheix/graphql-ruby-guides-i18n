---
title: タイムアウト
description: GraphQL 実行の打ち切り
sidebar:
  order: 5
---
`GraphQL::Schema::Timeout` プラグインを使って query の実行にタイムアウトを適用できます。例えば:

```ruby
class MySchema < GraphQL::Schema
  use GraphQL::Schema::Timeout, max_seconds: 2
end
```

`max_seconds` 経過後、新しい field の解決は行われません。代わりに、解決されなかった field には `errors` キーにエラーが追加されます。

__注意__: これは field の実行を中断するものではありません（中断すると [不具合がある](https://www.mikeperham.com/2015/05/08/timeout-rubys-most-dangerous-api/) ためです）。外部呼び出し（例: HTTP リクエストやデータベース query）を行っている場合は、その操作に対してライブラリ固有のタイムアウト（例: [Redis timeout](https://github.com/redis/redis-rb#timeouts)、[Net::HTTP](https://ruby-doc.org/stdlib-2.4.1/libdoc/net/http/rdoc/Net/HTTP.html) の `ssl_timeout`、`open_timeout`、`read_timeout`）を必ず使用してください。

## カスタムエラー処理

エラーをログするには、`handle_timeout` メソッドをオーバーライドした `GraphQL::Schema::Timeout` のサブクラスを用意してください:

```ruby
class MyTimeout < GraphQL::Schema::Timeout
  def handle_timeout(error, query)
    Rails.logger.warn("GraphQL Timeout: #{error.message}: #{query.query_string}")
  end
end

class MySchema < GraphQL::Schema
  use MyTimeout, max_seconds: 2
end
```

## タイムアウト時間のカスタマイズ

タイムアウト時間を動的に決める（または無効化する）には、サブクラス内で [`GraphQL::Schema::Timeout#max_seconds`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Timeout#max_seconds) をオーバーライドしてください。タイムアウトを完全に無効化するには、`max_seconds` が `false` を返すようにできます。

例えば:

```ruby
class MyTimeout < GraphQL::Schema::Timeout
  # Allow 10s for an incoming mutation, but don't apply any timeout for an admin user.
  def max_seconds(query)
    if query.context[:current_user]&.admin?
      false
    elsif query.mutation?
      10
    else
      super
    end
  end
end

# ...

class MySchema < GraphQL::Schema
  use MyTimeout, max_seconds: 5
end
```

## バリデーションと解析

query はユーザーから送られることがあり、schema に対する検証に長時間かかるように巧妙に作成される場合があります。

静的な検証ルールと解析器が実行できる秒数を制限して、検証タイムアウトエラーを返す前にかけられる時間を制御できます。デフォルトでは、検証と query 解析には 3 秒のタイムアウトがあります。このタイムアウトはカスタマイズするか、完全に無効化できます:

例えば:

```ruby
# Customize timeout (in seconds)
class MySchema < GraphQL::Schema
  # Applies to static validation and query analysis
  validate_timeout 10
end

# OR disable timeout completely
class MySchema < GraphQL::Schema
  validate_timeout nil
end
```

**注意:** この設定は Ruby の組み込み `Timeout` API を使用しており、IO 呼び出しを途中で中断して [非常に奇妙なバグ](https://www.mikeperham.com/2015/05/08/timeout-rubys-most-dangerous-api/) を引き起こす可能性があります。GraphQL-Ruby のバリデータはいずれも IO 呼び出しを行いませんが、この設定を使用したい場合で、IO を行うカスタム静的バリデータがある場合は、IO 安全な方法で実装することについて議論するために issue を開いてください。
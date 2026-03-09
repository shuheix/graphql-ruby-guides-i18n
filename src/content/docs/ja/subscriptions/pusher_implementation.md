---
title: Pusherの実装
description: Pusher経由のGraphQL subscriptions
sidebar:
  order: 6
pro: true
---
[GraphQL Pro](https://graphql.pro) には、任意の Ruby Web フレームワークで動作する [Redis](https://redis.io) と [Pusher](https://pusher.com) ベースの subscription システムが含まれています。

Pusher でアプリを作成し、[Ruby gem を設定する](https://github.com/pusher/pusher-http-ruby#global)と、これを GraphQL schema に接続できます。

## 動作の仕組み

この subscription 実装はハイブリッド方式を採用しています:

- __アプリ__ が GraphQL のクエリを受け取り実行します
- __Redis__ は後で更新を送るために subscription データを保存します
- __Pusher__ が購読クライアントへ更新を送信します

ライフサイクルは次のようになります:

- `subscription` クエリが HTTP POST でサーバに送信されます（`query` や `mutation` と同様です）
- レスポンスにはクライアントが購読できる Pusher チャネル ID（HTTP ヘッダ）が含まれます
- クライアントはその Pusher チャネルを開きます
- サーバが更新をトリガーすると、Pusher 経由で配信されます
- クライアントが購読解除すると、サーバは webhook を受け取り自分の subscription データを削除します

図にすると以下のようになります:

```
1. Subscription is created in your app

          HTTP POST
        .---------->   write to Redis
      📱            ⚙️ -----> 💾
        <---------'
        X-Subscription-ID: 1234


2. Client opens a connection to Pusher

          websocket
      📱 <---------> ☁️


3. The app sends updates via Pusher

      ⚙️ ---------> ☁️ ------> 📱
        POST           update
      (via gem)   (via websocket)


4. When the client unsubscribes, Pusher notifies the app

          webhook
      ⚙️ <-------- ☁️  (disconnect) 📱
```

この構成を使えば、自分でプッシュサーバをホストすることなく GraphQL subscriptions を利用できます。

## データベース設定

Subscriptions には永続的な Redis データベースが必要です。次のように設定してください:

```sh
maxmemory-policy noeviction
# optional, more durable persistence:
appendonly yes
```

そうしないと、Redis はメモリに収まらないデータを破棄します（詳細は ["Redis persistence"](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/) を参照してください）。

アプリで既に Redis を使っている場合は、データを分離し設定を調整する方法について ["Storing Data in Redis"](https://www.mikeperham.com/2015/09/24/storing-data-with-redis/) を参照してください。

## スキーマ設定

`Gemfile` に `redis` を追加します:

```ruby
gem 'redis'
```

そして `bundle install` を実行します。次に Redis インスタンスを作成します:

```ruby
# for example, in an initializer:
$graphql_subscriptions_redis = Redis.new # default connection
```

その Redis クライアントを Subscription の設定に渡します:

```ruby
class MySchema < GraphQL::Schema
  use GraphQL::Pro::PusherSubscriptions, redis: $graphql_subscriptions_redis
end
```

この接続は subscription 状態の管理に使われます。Redis へのすべての書き込みは `graphql:sub:` でプレフィックスされます。

永続性を管理するための設定が 2 つあります:

- `stale_ttl_s:`: 指定秒数更新がないと subscription データを期限切れにします。`stale_ttl_s` 経過後、データは Redis から期限切れになります。subscription が更新を受け取るたびに TTL はリフレッシュされます。（通常はバックエンド側でクリーンアップされるため必須ではありませんが、Redis に不要なクエリが溜まっている場合は、非常に長い時間の TTL を設定しておくと保険になります。）
- `cleanup_delay_s:`（デフォルト: `5`）: 作成直後の数秒間は subscription を削除しないようにします。通常は長い遅延は不要ですが、最初のレスポンスとクライアントの配信チャネル購読の間に遅延が観測される場合は、この設定で調整できます。

### Connection Pool

Redis への読み書き性能を向上させるために、`redis:` の代わりに `connection_pool:` を渡すことができます。これは [`connection_pool` gem](https://github.com/mperham/connection_pool) を使用します:

```ruby
  use GraphQL::Pro::PusherSubscriptions,
    connection_pool: ConnectionPool.new(size: 5, timeout: 5) { Redis.new },
```

### ブロードキャスト

[Broadcasts](/subscriptions/broadcast) を設定すると、単一の Pusher チャネルで複数クライアントへ更新を配信できます。

Broadcast チャネルは安定した予測可能な ID を持ちます。不正なクライアントの「盗み聞き」を防ぐために、トランスポートには [authorized Pusher channel](#認証) を使用してください。認可コード内で `.broadcast_subscription_id?` を使って broadcast かどうかを確認できます:

```ruby
# In your Pusher authorization endpoint:
channel_name = params[:channel_name]
MySchema.subscriptions.broadcast_subscription_id?(channel_name)
# => true | false
```

## 実行時の設定

実行中、GraphQL は `context` ハッシュに `subscription_id` を割り当てます。クライアントはその ID を更新受信に使うため、レスポンスヘッダで `subscription_id` を返す必要があります。

`result.context[:subscription_id]` を `X-Subscription-ID` ヘッダとして返してください。例えば:

```ruby
result = MySchema.execute(...)
# For subscriptions, return the subscription_id as a header
if result.subscription?
  response.headers["X-Subscription-ID"] = result.context[:subscription_id]
end
render json: result
```

こうすることで、クライアントはその ID を Pusher のチャネルとして使えます。

__CORS リクエスト__ の場合、クライアントがカスタムヘッダを読み取れるように特別なヘッダが必要です:

```ruby
if result.subscription?
  response.headers["X-Subscription-ID"] = result.context[:subscription_id]
  # Required for CORS requests:
  response.headers["Access-Control-Expose-Headers"] = "X-Subscription-ID"
end
```

詳細は ["Using CORS"](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS) を参照してください。

### ペイロード圧縮

[Pusher の 10kb メッセージ制限](https://support.pusher.com/hc/en-us/articles/4412243423761-What-Is-The-Message-Size-Limit-When-Publishing-an-Event-in-Channels-) による問題を緩和するため、subscription の `context` に `compress_pusher_payload: true` を指定できます。例えば:

```ruby
# app/controllers/graphql_controller.rb
def execute
  # ...
  # Somehow detect whether the client supports compressed payloads,
  # for example, User-Agent, query param, or request header:
  if client_supports_compressed_payloads?
    context[:compress_pusher_payload] = true
  end
  # ...
end
```

これにより、Pusher 経由で送信される subscription ペイロードは `result: "..."` の代わりに `compressed_result: "..."` を含めるようになります。圧縮ペイロードに対応するクライアント側の準備については、[Apollo Client](/javascript_client/apollo_subscriptions) または [Relay Modern](/javascript_client/relay_subscriptions) のドキュメントを参照してください。

クエリごとに `compress_pusher_payload: true` を設定することで、古いクライアントコードを実行しているクライアント（圧縮しない）をサポートしつつ、新しいクライアントに対して圧縮ペイロードを導入できます。

### バッチ配信

デフォルトでは、`PusherSubscriptions` は最大 10 件ずつのバッチで更新を送信します（[batch triggers](https://github.com/pusher/pusher-http-ruby#batches) を使用）。インストール時に `batch_size:` を渡すことでバッチサイズをカスタマイズできます。例:

```ruby
use GraphQL::Pro::PusherSubscriptions, batch_size: 1, ...
```

`batch_size: 1` にすると、`PusherSubscriptions` はバッチトリガーではなく単一トリガー API を使用します。

## Webhook 設定

クライアントが切断したときに Pusher からの webhook を受け取れるように、サーバ側で webhook を受信する必要があります。これによりローカルの subscription データベースを Pusher と同期できます。

Pusher の Web UI で "Channel existence" 用の webhook を追加してください。

{{ "/subscriptions/pusher_webhook_configuration.png" | link_to_img:"Pusher Webhook Configuration" }}

次に、Pusher の webhook を処理する Rack アプリをマウントします。例として Rails では次のようにします:

```ruby
# config/routes.rb

# Include GraphQL::Pro's routing extensions:
using GraphQL::Pro::Routes

Rails.application.routes.draw do
  # ...
  # Handle Pusher webhooks for subscriptions:
  mount MySchema.pusher_webhooks_client, at: "/pusher_webhooks"
end
```

こうすることで、Pusher の unsubscribe イベントに追従できます。

__または__、最初のリクエスト時にスキーマを遅延ロードするようルートを設定できます:

```ruby
# Provide the fully-qualified class name of your schema:
lazy_routes = GraphQL::Pro::Routes::Lazy.new("MySchema")
mount lazy_routes.pusher_webhooks_client, at: "/pusher_webhooks"
```

## 認証

Subscription の更新のプライバシーを確保するために、トランスポートには [private channel](https://pusher.com/docs/client_api_guide/client_private_channels) を使用することを推奨します。

private チャネルを使うには、クエリの context に `channel_prefix:` を追加します:

```ruby
MySchema.execute(
  query_string,
  context: {
    # If this query is a subscription, use this prefix for the Pusher channel:
    channel_prefix: "private-user-#{current_user.id}-",
    # ...
  },
  # ...
)
```

このプレフィックスは GraphQL 関連の Pusher チャネル名に適用されます。（プレフィックスは Pusher の要件として `private-` で始めてください。）

次に、あなたの [auth endpoint](https://pusher.com/docs/authenticating_users#implementing_private_endpoints) でログインユーザがチャネル名と一致することを確認できます:

```ruby
if params[:channel_name].start_with?("private-user-#{current_user.id}-")
  # success, render the auth token
else
  # failure, render unauthorized
end
```

## コンテキストのシリアライズ

Subscription の状態はデータベースに保存され、更新時に再ロードされるため、クエリの `context` をシリアライズして再ロードできる必要があります。

デフォルトでは [`GraphQL::Subscriptions::Serialize`](https://graphql-ruby.org/api-doc/GraphQL::Subscriptions::Serialize) の `dump` と `load` メソッドが使われますが、カスタム実装を提供することもできます。シリアライズロジックをカスタマイズするには、`GraphQL::Pro::PusherSubscriptions` を継承したサブクラスを作り、`#dump_context(ctx)` と `#load_context(ctx_string)` をオーバーライドします:

```ruby
class CustomSubscriptions < GraphQL::Pro::PusherSubscriptions
  def dump_context(ctx)
    context_hash = ctx.to_h
    # somehow convert this hash to a string, return the string
  end

  def load_context(ctx_string)
    # Given the string from the DB, create a new hash
    # to use as `context:`
  end
end
```

その後、スキーマには組み込みのものではなくカスタムの subscriptions クラスを使います:

```ruby
class MySchema < GraphQL::Schema
  # Use custom subscriptions instead of GraphQL::Pro::PusherSubscriptions
  # to get custom serialization logic
  use CustomSubscriptions, redis: $redis
end
```

これにより、コンテキストの再読み込みを細かく制御できます。

## ダッシュボード

[GraphQL-Pro Dashboard](/pro/dashboard) で subscription 状態を監視できます:

{{ "/subscriptions/redis_dashboard_1.png" | link_to_img:"Redis Subscription Dashboard" }}

{{ "/subscriptions/redis_dashboard_2.png" | link_to_img:"Redis Subscription Detail" }}

## 開発時のヒント

#### Subscription データのクリア

いつでも [GraphQL-Pro Dashboard](/pro/dashboard) の __"Reset"__ ボタン、あるいは Ruby から次のようにして subscription データベースをリセットできます:

```ruby
# Wipe all subscription data from the DB:
MySchema.subscriptions.clear
```

#### Pusher webhook を使った開発

開発環境で Pusher の webhook を受け取るには、Pusher は [ngrok の使用を推奨](https://support.pusher.com/hc/en-us/articles/203112227-Developing-against-and-testing-WebHooks) しています。ngrok は公開 URL を提供し、それを Pusher に設定することで、届いた webhook を開発環境に転送できます。

## クライアント設定

[Pusher JS client](https://github.com/pusher/pusher-js) をインストールしたら、以下のドキュメントを参照してください:

- [Apollo Client](/javascript_client/apollo_subscriptions)
- [Relay Modern](/javascript_client/relay_subscriptions)
- [GraphiQL](/javascript_client/graphiql_subscriptions)
- [urql](/javascript_client/urql_subscriptions)
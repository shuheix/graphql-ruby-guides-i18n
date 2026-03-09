---
title: Ably の実装
description: Ably 上での GraphQL subscriptions
sidebar:
  order: 7
pro: true
---
[GraphQL Pro](https://graphql.pro) には、任意の Ruby Web フレームワークで動作する [Redis](https://redis.io) と [Ably](https://ably.io) をベースにした subscription システムが含まれています。

Ably にアプリを作成したら、それをあなたの GraphQL schema に接続できます。

## 仕組み

この subscription 実装はハイブリッド方式を採用しています:

- __あなたのアプリ__ が GraphQL のクエリを受け取り実行します
- __Redis__ が後で更新を送るための subscription データを保存します
- __Ably__ が購読中のクライアントへ更新を送ります

ライフサイクルは次のようになります:

- `subscription` クエリが HTTP POST でサーバーに送られます（`query` や `mutation` と同様です）
- レスポンスにはクライアントが購読できる Ably チャンネル ID が含まれます（HTTP ヘッダーとして）
- クライアントはその Ably チャンネルを開きます
- サーバーが更新をトリガーすると、Ably チャンネル経由で配信されます
- クライアントが購読を解除すると、Ably が webhook でサーバーに通知し、サーバーは自身の subscription データを削除します

図で見るとこうなります:

```
1. Subscription is created in your app

          HTTP POST
        .---------->   write to Redis
      📱            ⚙️ -----> 💾
        <---------'
        X-Subscription-ID: 1234


2. Client opens a connection to Ably

          websocket
      📱 <---------> ☁️


3. The app sends updates via Ably

      ⚙️ ---------> ☁️ ------> 📱
        POST           update
      (via gem)   (via websocket)


4. When the client unsubscribes, Ably notifies the app

          webhook
      ⚙️ <-------- ☁️  (disconnect) 📱
```


この構成を使うことで、独自にプッシュサーバーをホストすることなく GraphQL subscriptions を利用できます。

## Ably のセットアップ
`Gemfile` に `ably-rest` を追加してください:

```ruby
gem 'ably-rest'
```

その後 `bundle install` を実行します。

## データベースの設定

Subscriptions では永続的な Redis データベースが必要です。以下のように設定してください:

```sh
maxmemory-policy noeviction
# optional, more durable persistence:
appendonly yes
```

そうしないと、Redis はメモリに収まらないデータを破棄してしまいます（詳しくは ["Redis persistence"](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/) を参照してください）。

既にアプリケーションで Redis を使用している場合は、データを分離したり設定を調整するためのオプションについて ["Storing Data in Redis"](https://www.mikeperham.com/2015/09/24/storing-data-with-redis/) を参照してください。

## Schema の設定

`Gemfile` に `redis` を追加してください:

```ruby
gem 'redis'
```

その後 `bundle install` を実行します。次に Redis インスタンスを作成します:

```ruby
# for example, in an initializer:
$graphql_subscriptions_redis = Redis.new # default connection
```

その Redis クライアントを Subscription の設定に渡します:

```ruby
class MySchema < GraphQL::Schema
  use GraphQL::Pro::AblySubscriptions,
    redis: $graphql_subscriptions_redis,
    ably: Ably::Rest.new(key: ABLY_API_KEY)
end
```

この接続は subscription 状態の管理に使われます。Redis への全ての書き込みは `graphql:sub:` でプレフィックスされます。

永続性を管理するための設定が 2 つあります:

- `stale_ttl_s:`: 指定した秒数更新がない場合に subscription データを期限切れにします。`stale_ttl_s` が経過すると Redis からデータが削除されます。subscription が更新を受けるたびに TTL はリフレッシュされます。（通常はバックエンド側で自動的にクリーンアップされるため不要ですが、Redis に古いクエリが溜まっている場合は長い期間で有効化しておくと安全です。）
- `cleanup_delay_s:`（デフォルト: `5`）: 作成直後の数秒間は subscription を削除しないようにする遅延です。通常は長くする必要はありませんが、初期レスポンスとクライアントが配信チャンネルに購読する間に遅延がある場合はこの値を調整してください。

### Connection Pool

Redis への読み書きを高速化するため、`redis:` の代わりに `connection_pool:` を渡すことができます。これは [`connection_pool` gem](https://github.com/mperham/connection_pool) を使用します:

```ruby
  use GraphQL::Pro::AblySubscriptions,
    connection_pool: ConnectionPool.new(size: 5, timeout: 5) { Redis.new },
    ably: Ably::Rest.new(key: ABLY_API_KEY)
```

### Broadcasts

[Broadcasts](/subscriptions/broadcast) を設定すると、単一の Ably チャンネルで多くのクライアントを更新できます。

Broadcast チャンネルは安定した予測可能な ID を持ちます。許可されていないクライアントの「盗み聞き」を防ぐために、トランスポートには [token authorization](#authorization) を使用してください。Broadcast チャンネルは `gqlbdcst:` という名前空間を使うため、認可コード内で `"gqlbdcst:*" => [ ... ]` のように受信権限を付与できます。（[encryption](#encryption) を使っている場合はプレフィックスが `ablyencr-gqlbdcst:` になります。）

## 実行設定

実行時、GraphQL は `context` ハッシュに `subscription_id` を割り当てます。クライアントはその ID を使って更新を待ち受けるため、レスポンスヘッダーに `subscription_id` を返す必要があります。

`result.context[:subscription_id]` を `X-Subscription-ID` ヘッダーとして返してください。例:

```ruby
result = MySchema.execute(...)
# For subscriptions, return the subscription_id as a header
if result.subscription?
  response.headers["X-Subscription-ID"] = result.context[:subscription_id]
end
render json: result
```

こうすることで、クライアントはその ID を Ably チャンネルとして使用できます。

__CORS リクエスト__ の場合、クライアントがカスタムヘッダーを読めるように特別なヘッダーを追加する必要があります:

```ruby
if result.subscription?
  response.headers["X-Subscription-ID"] = result.context[:subscription_id]
  # Required for CORS requests:
  response.headers["Access-Control-Expose-Headers"] = "X-Subscription-ID"
end
```

詳しくは ["Using CORS"](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS) を参照してください。

## Webhook の設定

クライアントが切断したときに Ably からの webhook を受け取れるようにサーバーを構成する必要があります。これによりローカルの subscription データベースを Ably と同期できます。

### サーバー

*注: 開発環境でセットアップする場合は、まず [Webhook を使った開発](#developing-with-webhooks) セクションを参照してください*

Ably からの webhook を処理する Rack アプリをマウントします。例えば Rails の場合:

```ruby
# config/routes.rb

# Include GraphQL::Pro's routing extensions:
using GraphQL::Pro::Routes

Rails.application.routes.draw do
  # ...
  # Handle webhooks for subscriptions:
  mount MySchema.ably_webhooks_client, at: "/ably_webhooks"
end
```

__あるいは__ ルートを遅延ロード（最初のリクエスト時にスキーマを読み込む）するように設定できます:

```ruby
# Provide the fully-qualified class name of your schema:
lazy_routes = GraphQL::Pro::Routes::Lazy.new("MySchema")
mount lazy_routes.ably_webhooks_client, at: "/ably_webhooks"
```

### Ably

1. Ably のダッシュボードに移動します
2. ご自身のアプリケーションをクリックします
3. **"Integrations"** タブを選択します
4. **"+ New Integration Rule"** ボタンをクリックします
5. **"Webhook"** の "Choose" ボタンをクリックします
6. 再度 **"Webhook"** の "Choose" ボタンをクリックします
7. URL フィールドに **（上で設定した webhooks のパスを含む）あなたの URL** を入力します
8. "Request Mode" で **"Batch request"** を選択します
9. "Source" で **"Presence"** を選択します
10. "Sign with key" で、あなたが提供した `ABLY_API_KEY` のプレフィックスに合う API Key プレフィックスを選択します
11. **"Create"** をクリックします

## Authorization（認証）
<a name="authorization"></a>

Ably の [token authentication](https://www.ably.io/documentation/realtime/authentication#token-authentication) を使うには、アプリにエンドポイントを実装できます。例:

```ruby
class AblyController < ActionController::Base
  def auth
    render status: 201, json: ably_rest_client.auth.create_token_request(
      capability: { '*' => ['presence', 'subscribe'] },
      client_id: 'graphql-subscriber',
    )
  end
end
```

[Ably のチュートリアル](https://www.ably.io/tutorials/webhook-chuck-norris#tutorial-step-4) でも設定の一部が示されています。

## 暗号化
<a name="encryption"></a>

GraphQL subscriptions で Ably の [end-to-end encryption](https://www.ably.io/documentation/realtime/encryption) を使うことができます。有効にするには、設定に `cipher_base:` を追加します:

```ruby
  use GraphQL::Pro::AblySubscriptions,
    redis: $graphql_subscriptions_redis,
    ably: Ably::Rest.new(key: ABLY_API_KEY),
    # Add `cipher_base:` to enable end-to-end encryption
    cipher_base: "ff16381ae2f2b6c6de6ff696226009f3"
```

（任意のランダムな文字列でかまいません。例: `ruby -e "require 'securerandom'; puts SecureRandom.hex"`。）

また、クライアントが subscription 更新を復号できるようにヘッダーでキーを返してください。キーは `context[:ably_cipher_base64]` に入れられ、`graphql-ruby-client` は `X-Subscription-Key` ヘッダーでそれを受け取ることを期待しています:

```ruby
result = MySchema.execute(...)
# For subscriptions, return the subscription_id as a header
if result.subscription?
  response.headers["X-Subscription-ID"] = result.context[:subscription_id]
  # Also return the encryption key so that clients
  # can decode subscription updates
  response.headers["X-Subscription-Key"] = result.context[:ably_cipher_base64]
end
```

（CORS リクエストを使っている場合は `Access-Control-Expose-Headers` に `X-Subscription-Key` を追加してください）

この設定では、

- `GraphQL::Pro::AblySubscriptions` はサブスクリプションごとの鍵（`cipher_base` と subscription ID を使って生成）を作成し、Ably ペイロードを暗号化します
- その鍵は `X-Subscription-Key` でクライアントに返されます
- クライアントは受信メッセージの復号にその鍵を使用します

__下位互換性:__ `GraphQL::Pro::AblySubscriptions` は `query.context[:ably_cipher_base64]` が存在する場合に限りペイロードを暗号化します。`cipher_base:` を設定する前に作られたサブスクリプションは暗号化されません（鍵がなく、クライアントも復号できないためです）。

## コンテキストのシリアライズ

subscription の状態はデータベースに保存され、更新をプッシュする際に再ロードされるため、クエリの `context` をシリアライズして再ロードする必要があります。

デフォルトでは、[`GraphQL::Subscriptions::Serialize`](https://graphql-ruby.org/api-doc/GraphQL::Subscriptions::Serialize) の `dump` と `load` メソッドで行われますが、カスタム実装を提供することもできます。シリアライズロジックをカスタマイズするには、`GraphQL::Pro::AblySubscriptions` をサブクラス化し、`#dump_context(ctx)` と `#load_context(ctx_string)` をオーバーライドしてください:

```ruby
class CustomSubscriptions < GraphQL::Pro::AblySubscriptions
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

その後、スキーマでは組み込みのクラスの代わりにカスタムの subscriptions クラスを使用します:

```ruby
class MySchema < GraphQL::Schema
  # Use custom subscriptions instead of GraphQL::Pro::AblySubscriptions
  # to get custom serialization logic
  use CustomSubscriptions, ...
end
```

これによりコンテキスト再ロードの挙動を細かく制御できます。

## ダッシュボード

[GraphQL-Pro Dashboard](/pro/dashboard) で subscription 状態を監視できます:

{{ "/subscriptions/redis_dashboard_1.png" | link_to_img:"Redis Subscription Dashboard" }}

{{ "/subscriptions/redis_dashboard_2.png" | link_to_img:"Redis Subscription Detail" }}

## 開発時のヒント

#### subscription データのクリア

いつでも [GraphQL-Pro Dashboard](/pro/dashboard) の __"Reset"__ ボタン、または Ruby で次のようにして subscription データベースをリセットできます:

```ruby
# Wipe all subscription data from the DB:
MySchema.subscriptions.clear
```

#### Webhook を使った開発

開発中に webhook を受け取るには、[ngrok を使う](https://www.ably.io/tutorials/webhook-chuck-norris) と便利です。ngrok は公開 URL を提供し、それを Ably に設定することで、その URL に届いたフックを開発環境へ転送してくれます。

## クライアントの設定

[Ably JS client](https://github.com/ably/ably-js) をインストールしたら、以下のクライアント向けドキュメントを参照してください:

- [Apollo Client](/javascript_client/apollo_subscriptions)
- [Relay Modern](/javascript_client/relay_subscriptions)
- [GraphiQL](/javascript_client/graphiql_subscriptions)

<a name="developing-with-webhooks"></a>
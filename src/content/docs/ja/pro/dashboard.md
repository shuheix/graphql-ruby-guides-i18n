---
title: ダッシュボード
description: GraphQL-Pro のダッシュボードのインストール
sidebar:
  order: 4
pro: true
---
[GraphQL-Pro](https://graphql.pro) には [Operation Store](/operation_store/overview) および [subscriptions](/subscriptions/pusher_implementation) を監視するためのウェブダッシュボードが含まれています。

<!-- TODO image -->

## インストール

ダッシュボードを接続するには、`routes.rb` に追加します。

```ruby
# config/routes.rb

# Include GraphQL::Pro's routing extensions:
using GraphQL::Pro::Routes

Rails.application.routes.draw do
  # ...
  # Add the GraphQL::Pro Dashboard
  # TODO: authorize, see below
  mount MySchema.dashboard, at: "/graphql/dashboard"
end
```

この設定により、`/graphql/dashboard` で利用可能になります。

ダッシュボードは Rack アプリケーションなので、Sinatra や他の Rack アプリにマウントできます。

#### schema の遅延読み込み

あるいは、ダッシュボードが最初のリクエスト時に schema を読み込むように設定できます。そのためには、スキーマクラスの完全修飾名を文字列で渡して `GraphQL::Pro::Routes::Lazy` を初期化します。例えば:

```ruby
Rails.application.routes.draw do
  # ...
  # Add the GraphQL::Pro Dashboard
  # TODO: authorize, see below
  lazy_routes = GraphQL::Pro::Routes::Lazy.new("MySchema")
  mount lazy_routes.dashboard, at: "/graphql/dashboard"
end
```

この設定により、ダッシュボードが最初のリクエストを処理するときに `MySchema` が読み込まれます。ルート作成時に GraphQL schema 全体を読み込まないため、開発時のアプリケーションの起動が高速化されます。

## ダッシュボードの認可

`/graphql/dashboard` は保存された operations を削除できるため、管理者ユーザーのみが閲覧できるようにしてください。

### Rails のルーティング制約

例えば、[Rails のルーティング制約](https://api.rubyonrails.org/v5.1/classes/ActionDispatch/Routing/Mapper/Scoping.html#method-i-constraints) を使ってアクセスを認可されたユーザーに制限します。例:

```ruby
# Check the secure session for a staff flag:
STAFF_ONLY = ->(request) { request.session["staff"] == true }
# Only serve the GraphQL Dashboard to staff users:
constraints(STAFF_ONLY) do
  mount MySchema.dashboard, at: "/graphql/dashboard"
end
```

### Rack のベーシック認証

ウェブ表示の前に `Rack::Auth::Basic` ミドルウェアを挿入します。これにより、ダッシュボードにアクセスした際にユーザー名とパスワードの入力が求められます。

```ruby
graphql_dashboard = Rack::Builder.new do
  use(Rack::Auth::Basic) do |username, password|
    username == ENV.fetch("GRAPHQL_USERNAME") && password == ENV.fetch("GRAPHQL_PASSWORD")
  end

  run MySchema.dashboard
end
mount graphql_dashboard, at: "/graphql/dashboard"
```
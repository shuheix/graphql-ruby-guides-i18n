---
title: はじめに
description: アプリに GraphQL::Pro::OperationStore を追加する
sidebar:
  order: 1
pro: true
---
アプリで `GraphQL::Pro::OperationStore` を使うには、次の手順に従ってください:

- [依存関係を確認する](#依存関係)
- [データベースを準備する](#データベースの準備)
- [`OperationStore` をスキーマに追加する](#OperationStoreを追加)
- [ダッシュボードと同期 API のルートを追加する](#ルートを追加)
- [コントローラを更新して永続化クエリをサポートする](#コントローラを更新)
- [クライアントを追加してクエリの同期を開始する](/operation_store/client_workflow)

## 依存関係

`OperationStore` はアプリ環境に2つの gem が必要です:

- [ActiveRecord](/operation_store/active_record_backend) または [Redis](/operation_store/redis_backend) による永続化。（別の ORM やバックエンドを使っていますか？サポートを要望するには {% open_an_issue "Backend support request for OperationStore" %} を作成してください！）
- `Rack`: ダッシュボードと Sync API を提供するために必要です。（Rails では `config/routes.rb` で提供されます。）

これらは Rails によってデフォルトでバンドルされています。

## データベースの準備

ActiveRecord でデータを保存する場合は、テーブルを用意するために [データベースをマイグレーションしてください](/operation_store/active_record_backend)。

## OperationStoreを追加

ストレージをスキーマに接続するには、プラグインを追加してください:

```ruby
class MySchema < GraphQL::Schema
  # Add it _after_ other tracing-related features, for example:
  # use GraphQL::Tracing::DataDogTracing
  # ...
  use GraphQL::Pro::OperationStore
end
```

この機能は必ず他の [Tracing](/queries/tracing) ベースの機能の後に追加してください。そうすることで、それらの機能がロード済みのクエリ文字列にアクセスできます。そうしないと "No query string was present" エラーが発生することがあります。

デフォルトでは ActiveRecord を使用します。以下のオプションも指定できます:

- `redis:` — [Redis backend](/operation_store/redis_backend) を使う場合に指定します。
- `backend_class:` — カスタム永続化を実装する場合に指定します。

また、`default_touch_last_used_at: false` を指定すると「last used at」の更新を無効にできます。（クエリごとに `context[:operation_store_touch_last_used_at] = true|false` で設定することもできます。）

## ルートを追加

`OperationStore` を使うには、アプリに次の 2 つのルートを追加してください:

```ruby
# config/routes.rb

# Include GraphQL::Pro's routing extensions:
using GraphQL::Pro::Routes

Rails.application.routes.draw do
  # ...
  # Add the Dashboard
  # TODO: authorize, see the dashboard guide
  mount MySchema.dashboard, at: "/graphql/dashboard"
  # Add the Sync API (authorization built-in)
  mount MySchema.operation_store_sync, at: "/graphql/sync"
end
```

MySchema.operation_store_sync はクライアントからのプッシュを受け取ります。どのようにこのエンドポイントが使われるかは [クライアントワークフロー](/operation_store/client_workflow) を参照してください。

MySchema.dashboard は `/graphql/dashboard` で表示される `OperationStore` のウェブビューを含みます。認可などの詳細は [ダッシュボードガイド](/pro/dashboard) を参照してください。

{{ "/operation_store/graphql_ui.png" | link_to_img:"GraphQL Persisted Operations Dashboard" }}

`operation_store_sync` と `dashboard` はどちらも Rack アプリなので、Rails、Sinatra、または任意の Rack アプリにマウントできます。

__あるいは__、最初のリクエスト時にスキーマを遅延ロードするようにルートを設定することもできます:

```ruby
# Provide the fully-qualified class name of your schema:
lazy_routes = GraphQL::Pro::Routes::Lazy.new("MySchema")
mount lazy_routes.dashboard, at: "/graphql/dashboard"
mount lazy_routes.operation_store_sync, at: "/graphql/sync"
```

### 可視性プロファイルを使用する場合

`operation_store_sync` にプロファイル名を渡すことで、受信する操作に [visibility profile](/authorization/visibility#visibility-profiles) を適用できます。例えば:

```ruby
mount MySchema.operation_store_sync(visibility_profile: :public_api), at: "/graphql/sync"
# or:
mount lazy_routes.operation_store_sync(visibility_profile: :public_api), at: "/graphql/sync"
```

これにより、新しく同期されるすべての操作にそのプロファイルが適用されます。（既に同期されている操作には影響しません。）

## コントローラを更新

GraphQL の context に `operation_id:` を追加してください:

```ruby
# app/controllers/graphql_controller.rb
context = {
  # Relay / Apollo 1.x:
  operation_id: params[:operationId]
  # Or, Apollo Link:
  # operation_id: params[:extensions][:operationId]
}

MySchema.execute(
  # ...
  context: context,
)
```

`OperationStore` はデータベースから操作を取得するために `operation_id` を使用します。

`params[:query]` からの GraphQL を拒否する方法の詳細については、[サーバー管理](/operation_store/server_management) を参照してください。

## 次のステップ

[クライアントワークフロー](/operation_store/client_workflow) を使って、操作を同期してください。
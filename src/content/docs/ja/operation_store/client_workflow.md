---
title: クライアントのワークフロー
description: クライアントをシステムに追加し、操作をデータベースと同期します。
sidebar:
  order: 4
pro: true
---
クライアントアプリで persisted queries を使うには、次を行う必要があります:

- `OperationStore` を設定します（[Getting Started](/operation_store/getting_started) を参照してください）
- システムに[クライアントを追加](#クライアントを追加)
- クライアントからサーバーへ[操作の同期](#同期)
- クライアントアプリから `params[:operationId]` を送信する（[クライアントの使用方法](#クライアントの使用方法)）

このドキュメントは、`OperationStore` を使うための JavaScript クライアントライブラリである [graphql-ruby-client sync](/javascript_client/sync) についても触れています。

## クライアントを追加

クライアントは[ダッシュボード](/operation_store/getting_started#add-routes)から登録します:

{{ "/operation_store/add_a_client.png" | link_to_img:"Add a Client for Persisted Queries" }}

デフォルトの `secret` が自動で用意されますが、独自の値を入力することもできます。`secret` は [HMAC 認証](/operation_store/access_control) に使われます。

（これのための Ruby API に興味がありますか? {% open_an_issue "OperationStore Ruby API" %} を開くか、`support@graphql.pro` にメールしてください。）

## 同期

クライアントが登録されると、[Sync API](/operation_store/getting_started#add-routes) を通じてクエリをサーバーへプッシュできます。

最も簡単な同期方法は、JavaScript で書かれたコマンドラインツールである `graphql-ruby-client sync` を使うことです（[Sync Guide](/javascript_client/sync)）。

簡単に言うと、このツールは:

- 指定した `--path` 内の `.graphql` ファイルや `relay-compiler` の出力から GraphQL クエリを見つける
- 指定した `--client` と `--secret` に基づいて [認証ヘッダ](/operation_store/access_control) を追加する
- 指定した `--url` に operations を送信する
- 指定した `--outfile` に JavaScript モジュールを生成する

例えば:

{{ "/operation_store/sync_example.png" | link_to_img:"OperationStore client sync" }}

別の言語での同期方法については、[JavaScript 実装](https://github.com/rmosolgo/graphql-ruby/tree/master/javascript_client) を参考にするか、{% open_an_issue "Implementing operation sync in another language" %} を開くか、`support@graphql.pro` にメールしてください。

## クライアントの使用方法

Relay Modern、Apollo 1.x、Apollo Link、またはプレーンな JavaScript と OperationStore を使う方法については、[Sync Guide](/javascript_client/sync) を参照してください。

別のクライアントから保存された operations を実行するには、`operationId` という名前のパラメータを送信します。`operationId` は次のように構成されます:


```ruby
 {
   # ...
   operationId: "my-relay-app/ce79aa2784fc..."
   #            ^ client id  / ^ operation id
 }
```

サーバーはその値を使ってデータベースから operation を取得します。

### 次のステップ

`OperationStore` の [認証](/operation_store/access_control) について詳しく学ぶか、[サーバー管理](/operation_store/server_management) のいくつかのヒントをお読みください。
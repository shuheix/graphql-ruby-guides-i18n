---
title: 概要
description: 永続化されたクエリの仕組みと、OperationStore がそれをどのように実装するかを学びます。
sidebar:
  order: 0
pro: true
---
`GraphQL::Pro::OperationStore` は `Rack` とストレージバックエンド（[ActiveRecord](/operation_store/active_record_backend) または [Redis](/operation_store/redis_backend)）を使って、あなたの GraphQL システムのために正規化・重複排除された永続化されたクエリのデータベースを維持します。

このガイドでは、次の内容を扱います:

- [永続化されたクエリの説明](#永続化されたクエリとは)
- [なぜ永続化されたクエリを使うのか](#なぜ永続化されたクエリを使うのか)
- [OperationStore の仕組み](#仕組み)、簡潔な概要

ほかのガイドでは、次の内容を詳しく読むことができます:

- [導入](/operation_store/getting_started): アプリに `OperationStore` をインストールする方法
- [クライアントのワークフロー](/operation_store/client_workflow): クライアントアプリでのワークフローと使用法
- [認証](/operation_store/access_control): sync API の認証について
- [サーバー管理](/operation_store/server_management): システム稼働後の管理

また、[GitHub 上のデモアプリ](https://github.com/rmosolgo/graphql-pro-operation-store-example) も参照できます。

## 永続化されたクエリとは？

「永続化されたクエリ」は、サーバーに保存され、クライアントが参照（reference）によって呼び出す GraphQL のクエリ（`query`、`mutation`、または `subscription`）です。この方式では、クライアントはネットワーク越しに GraphQL の全文を送信しません。代わりに、クライアントは次の情報を送ります:

- クライアント名（どのクライアントがリクエストしているかを識別するため）
- クエリアイリアス（どの保存済み操作を実行するかを指定するため）
- クエリ変数（保存された操作に対する値を提供するため）

その後、サーバーはその識別子を使ってデータベースから完全な GraphQL ドキュメントを取得します。

永続化されたクエリを使わない場合、クライアントは全文を送信します:

```ruby
# Before, without persisted queries
query_string = "query GetUserDetails($userId: ID!) { ... }"

MyGraphQLEndpoint.post({
  query: query_string,
  operationName: "GetUserDetails",
  variables: { userId: "100" },
})
```


しかし永続化されたクエリを使うと、サーバー側に既にコピーがあるため全文は送信されません:

```ruby
# After, with persisted queries:
MyGraphQLEndpoint.post({
  operationId: { "relay-app-v1/fc84dbba3623383fdc",
  #               client name / query alias (eg, @relayHash)
  variables: { userId: "100" },
})
```

## なぜ永続化されたクエリを使うのか

永続化されたクエリを使うことで、あなたの GraphQL システムのセキュリティ、効率性、可視性が向上します。

### セキュリティ

永続化されたクエリは、任意の GraphQL クエリを拒否できるようにすることでセキュリティを改善します。クエリのデータベースがホワイトリストの役割を果たすため、予期しないクエリがシステムに到達することを防げます。

例えば、すべてのクライアントが永続化されたクエリに移行した後、本番環境では任意の GraphQL を拒否できます:

```ruby
# app/controllers/graphql_controller.rb
if Rails.env.production? && params[:query].present?
  # Reject arbitrary GraphQL in production:
  render json: { errors: [{ message: "Raw GraphQL is not accepted" }]}
else
  # ...
end
```

### 効率性

永続化されたクエリは、HTTP トラフィックを減らすことでシステムの効率性を高めます。GraphQL を毎回送る代わりに、クエリはデータベースから取得されるため、リクエストで必要な帯域が小さくなります。

例えば、永続化されたクエリを使う前は、クエリ全文がサーバーに送られていました:

{{ "/operation_store/request_before.png" | link_to_img:"GraphQL request without persisted queries" }}

しかし永続化されたクエリを使った後は、サーバーに送られるのはクエリの識別情報だけになります:

{{ "/operation_store/request_after.png" | link_to_img:"GraphQL request with persisted queries" }}

### 可視性

永続化されたクエリは、GraphQL の使用状況を一元的に追跡できるため可視性を向上させます。`OperationStore` は type、field、argument の使用状況のインデックスを維持するので、トラフィックの分析が可能です。

{{ "/operation_store/operation_index.png" | link_to_img:"Index of GraphQL usage with persisted queries" }}

## 仕組み

`OperationStore` はデータベース内のテーブルを使って、正規化・重複排除された GraphQL 文字列を保存します。データベースは不変であり、新しい operation は追加され得ますが、既存の operation が変更されたり削除されたりすることはありません。

クライアントが [operations を sync する](/operation_store/client_workflow) と、リクエストは [認証](/operation_store/access_control) され、受信した GraphQL は検証・正規化され、必要であればデータベースに追加されます。また、受信したクライアント名はペイロード内のすべての operation に関連付けられます。

そして実行時には、クライアントが永続化されたクエリを実行するために operation ID を送ります。`params` では次のように表れます:

```ruby
params[:operationId] # => "relay-app-v1/810c97f6631001..."
```

`OperationStore` はこれを使ってデータベースから一致する operation を取得します。その後は通常どおりクエリが評価されます。

## 導入

`OperationStore` をアプリに追加する方法は、[導入ガイド](/operation_store/getting_started) を参照してください。
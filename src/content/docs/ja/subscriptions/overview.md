---
title: 概要
description: GraphQL-Ruby における Subscriptions の紹介
sidebar:
  order: 0
---
_Subscriptions_ は、GraphQL クライアントが特定のイベントを監視し、それらのイベントが発生したときにサーバーから更新を受け取れるようにします。これにより、WebSocket プッシュのようなライブ更新をサポートします。Subscriptions はいくつかの新しい概念を導入します:

- __Subscription type__ は subscription クエリのエントリポイントです
- __Subscription classes__ は初回の subscription リクエストやその後の更新を処理する resolver です
- __Triggers__ は更新プロセスを開始します
- __Implementation__ は更新を実行・配信するためのアプリケーション固有のメソッドを提供します
- __Broadcasts__ は同じ GraphQL 結果を任意の数のサブスクライバーに送信できます

## Subscription Type について

`subscription` は `query` や `mutation` と同様に、あなたの GraphQL schema のエントリポイントです。これはルートレベルの `GraphQL::Schema::Object` であるあなたの `SubscriptionType` によって定義されます。

詳細は [Subscription Type guide](subscriptions/subscription_type) を参照してください。

## Subscription Classes について

[`GraphQL::Schema::Subscription`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Subscription) は subscription 固有の振る舞いを持つ resolver クラスです。各 subscription field は subscription class によって実装する必要があります。

詳細は [Subscription Classes guide](subscriptions/subscription_classes) を参照してください。

## Triggers について

アプリケーション内でイベントが発生した後、_triggers_ は名前とペイロードを GraphQL に送信して更新プロセスを開始します。

詳細は [Triggers guide](subscriptions/triggers) を参照してください。

## Implementation について

GraphQL コンポーネントに加えて、アプリケーション側でいくつかの subscription 関連の基盤を用意する必要があります。例えば:

- __state management__: アプリケーションは誰がどの subscription に登録しているかをどのように管理しますか？
- __transport__: アプリケーションはどのようにペイロードをクライアントに配信しますか？
- __queueing__: アプリケーションは再実行する subscription query の処理をどのように分配しますか？

詳細は [Implementation guide](subscriptions/implementation) を参照するか、[ActionCable implementation](subscriptions/action_cable_implementation)、[Pusher implementation](subscriptions/pusher_implementation)、[Ably implementation](subscriptions/ably_implementation) を確認してください。

## Broadcasts について

デフォルトでは、上記の subscription 実装は各 subscription を完全に独立して扱います。しかし、この挙動は broadcasts を設定することで最適化できます。詳細は [Broadcast guide](subscriptions/broadcast) を参照してください。

## Multi-Tenant について

GraphQL の subscriptions でマルチテナンシーをサポートする方法については、[Multi-tenant guide](subscriptions/multi_tenant) を参照してください。
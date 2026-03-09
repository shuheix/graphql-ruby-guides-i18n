---
title: Action Cable の実装
description: ActionCable を用いた GraphQL subscriptions
sidebar:
  order: 4
---
[ActionCable](https://guides.rubyonrails.org/action_cable_overview.html) は Rails 5+ 上で GraphQL subscriptions を配信するための優れたプラットフォームです。メッセージの受け渡し（`broadcast` 経由）とトランスポート（websocket 経由の `transmit`）を扱います。

始めるには、API ドキュメントの例を参照してください: [`GraphQL::Subscriptions::ActionCableSubscriptions`](https://graphql-ruby.org/api-doc/GraphQL::Subscriptions::ActionCableSubscriptions)。GraphQL-Ruby にはテスト用のモック ActionCable 実装も含まれています: [`GraphQL::Testing::MockActionCable`](https://graphql-ruby.org/api-doc/GraphQL::Testing::MockActionCable)。

クライアントでの使用例:

- [Apollo Client](/javascript_client/apollo_subscriptions)
- [Relay Modern](/javascript_client/relay_subscriptions).
- [GraphiQL](/javascript_client/graphiql_subscriptions)
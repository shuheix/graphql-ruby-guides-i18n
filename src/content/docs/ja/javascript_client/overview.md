---
title: 概要
description: GraphQL-Ruby の JavaScript クライアント graphql-ruby-client の導入
sidebar:
  order: 0
---
GraphQL-Ruby 用の JavaScript クライアントとして `graphql-ruby-client` があります。

NPM または Yarn からインストールできます:

```sh
yarn add graphql-ruby-client
# Or:
npm install graphql-ruby-client
```

ソースコードは [graphql-ruby リポジトリ](https://github.com/rmosolgo/graphql-ruby/tree/master/javascript_client) にあります。

機能の詳細については以下のガイドを参照してください:

- [sync CLI](javascript_client/sync): [graphql-pro](https://graphql.pro) の永続化クエリバックエンドで使用します。
- サブスクリプションのサポート:
  - [Apollo 統合](/javascript_client/apollo_subscriptions)
  - [Relay 統合](/javascript_client/relay_subscriptions)
  - [urql 統合](/javascript_client/urql_subscriptions)
  - [GraphiQL 統合](/javascript_client/graphiql_subscriptions)
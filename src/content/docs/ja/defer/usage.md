---
title: 使い方
description: クライアント側での @defer の使用
sidebar:
  order: 2
pro: true
---
`@defer` は [GraphQL directive](https://graphql.org/learn/queries/#directives) で、サーバーにフィールドを特殊な方法で実行するよう指示します:

```graphql
query GetPlayerInfo($handle: String!){
  player(handle: $handle) {
    name
    # Send this field later, to avoid slowing down the initial response:
    topScore(from: 2000, to: 2020) @defer
  }
}
```

The directives `@skip` and `@include` are built into any GraphQL server and client, but `@defer` requires special attention.

Apollo-Client [現在 @defer directive をサポートしています](https://www.apollographql.com/docs/react/data/defer/)。

`@defer` は `label:` オプションも受け付けます。クエリに含まれている場合、送信されるパッチにそのラベルが含まれます（例: `@defer(label: "patch1")`）。

別のクライアントで `@defer` を使いたいですか？ ぜひ {% open_an_issue "Client support for @defer with ..." %} または `support@graphql.pro` にメールしてください。こちらで詳しく調査いたします。

## 次のステップ

`@defer` をサポートするように [サーバーをセットアップしてください](/defer/setup)。
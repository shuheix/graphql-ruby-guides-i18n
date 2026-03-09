---
title: 概要
description: "「@defer」とは何か、なぜ使うのか？"
sidebar:
  order: 0
pro: true
---
`@defer` は、サーバーからクライアントへ GraphQL レスポンスをストリーミングするための [directive](/type_definitions/directives) です。

レスポンスをストリーミングすることで、サーバーは最重要（または最も早く利用可能な）データを _最初に_ 送信し、その後に二次的なデータを順次送信できます。

`@defer` は最初に [Lee Byron（React Europe 2015での講演）](https://youtu.be/ViXL0YQnioU?t=768) で説明され、[Apollo（2018年）](https://blog.apollographql.com/introducing-defer-in-apollo-server-f6797c4e9d6e) で実験的にサポートされました。

`@stream` は `@defer` に似ていますが、リストの項目を1つずつ返します。詳細は [Stream ガイド](/defer/stream) を参照してください。

## 例

GraphQL クエリは大きく複雑になりがちで、多くの計算や遅い外部サービスへの依存を伴うことがあります。

この例では、ローカルサーバーはアイテム（「deck」）の索引を保持していますが、アイテムデータ（「card」）自体はリモートサーバーでホストされています。したがって、そのデータを提供するためには GraphQL クエリがリモート呼び出しを行う必要があります。

`@defer` を使わない場合、最後のフィールドの解決が終わるまでクエリ全体がブロックされます。

{{ "https://user-images.githubusercontent.com/2231765/53442028-4a122b00-39d6-11e9-8e33-b91791bf3b98.gif" | link_to_img:"Rails without defer" }}

しかし、遅いフィールドに `@defer` を追加できます:

```diff
  deck {
    slots {
      quantity
-     card
+     card @defer {
        name
        price
      }
    }
  }
```

すると、レスポンスは少しずつクライアントへストリーミングされるため、ページは段階的に読み込まれます:

{{ "https://user-images.githubusercontent.com/2231765/53442027-4a122b00-39d6-11e9-8d7b-feb7a4f7962a.gif" | link_to_img:"Rails with defer" }}


このようにして、クライアントはデータ読み込み中でもアプリのレスポンスが速く感じられます。

フルデモは https://github.com/rmosolgo/graphql_defer_example をご覧ください。

## 考慮事項

- `@defer` はレスポンスに若干のオーバーヘッドを追加するため、慎重に適用してください。
- `@defer` は単一スレッドで動作します。`@defer` されたフィールドは順序どおりに評価されますが、チャンクごとに返されます。

## 次の手順

[サーバーをセットアップする](/defer/setup) ことで `@defer` をサポートするように設定するか、[クライアントでの使用法](/defer/usage) をお読みください。
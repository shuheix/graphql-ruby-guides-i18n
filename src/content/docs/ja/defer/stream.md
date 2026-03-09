---
title: ストリーム
description: "@stream を使ってリストの項目を1件ずつ受け取る"
sidebar:
  order: 3
pro: true
---
`@stream` は `@defer` と非常によく似ていますが、list の field にのみ適用されます。ある field に `@stream` があり、かつその field がリストを返す場合、リスト内の各項目はパッチとしてクライアントに順次返されます。`@stream` は [GraphQL 仕様への提案](https://github.com/graphql/graphql-wg/blob/main/rfcs/DeferStream.md) で説明されています。

__注:__ `@stream` は GraphQL-Pro 1.21.0 で追加され、GraphQL-Ruby 1.13.6+ が必要です。

## 導入

schema で `@stream` をサポートするには、`use GraphQL::Pro::Stream` を追加します:

```ruby
class MySchema < GraphQL::Schema
  # ...
  use GraphQL::Pro::Stream
end
```

さらに、レスポンスの遅延部分を処理するようコントローラを更新する必要があります。詳細は [@defer のセットアップガイド](defer/setup#sending-streaming-responses) を参照してください。(`@stream` は `@defer` と同じデファーラルパイプラインを使用するため、同じセットアップ手順が適用されます。)

## 使用方法

その後、クエリに `@stream` を含めることができます。例えば:

```ruby
{
  # Send each movie in its own patch:
  nowPlaying @stream {
    title
    director { name }
  }
}
```

`@stream` がリストでない field に適用されている場合は無視されます。

`@stream` はいくつかの引数をサポートします:

- `if: Boolean = true`: `false` のときは、そのリストは _ストリーミングされません_。代わりに、すべての項目が同期的に返されます。
- `label: String`: 指定すると、パッチ内に `"label": "..."` としてその文字列が返されます。
- `initialCount: Int = 0`: この数だけのリスト項目が同期的に返されます。（リストの長さが `initialCount` より短い場合は、リスト全体が同期的に返されます。）
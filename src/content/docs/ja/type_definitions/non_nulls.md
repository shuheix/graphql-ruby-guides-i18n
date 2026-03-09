---
title: 非 null types
description: 必ず存在しなければならない値
sidebar:
  order: 7
---
GraphQL の _non-null_ の概念は [Schema 定義言語](https://graphql.org/learn/schema/#non-null)（SDL）で `!` によって表現されます。例えば:

```graphql
type User {
  # This field _always_ returns a String, never returns `null`
  handle: String!
  # `since:` _must_ be passed a `DateTime` value, it can never be omitted or passed `null`
  followers(since: DateTime!): [User!]!
}
```

Ruby では、この概念は fields に対しては `null:`、arguments に対しては `required:` で表現します。

## 非 null の戻り値

フィールドの戻り値で `!` が使われている場合（上の `handle: String!` のように）、その field は _決して_ `nil` を返さないことを意味します。

Ruby で field を non-null にするには、field 定義で `null: false` を使用します:

```ruby
# equivalent to `handle: String!` above
field :handle, String, null: false
```

これは、その field が _決して_ `nil` にならないことを意味します（もし `nil` になった場合は、以下で説明する通りレスポンスから削除されます）。

### 非 null のエラー伝播

もし non-null な field が `nil` を返した場合、その選択部分全体はレスポンスから削除され `nil` に置き換えられます。もしこの削除が別の不正な `nil` を生む場合は、ルートの "data" キーに到達するまで上方向に連鎖します。これは型付けの厳しい言語のクライアントをサポートするためです。どの non-null な field も _決して_ `null` を返さないので、クライアント開発者はそれに依存できます。

## 非 null のargument

arguments に `!` が使われている場合（上の `followers(since: DateTime!)` のように）、その argument はクエリを実行するために _必須_ であることを意味します。その argument に対して値がないクエリは直ちに拒否されます。

arguments はデフォルトで non-null（必須）です。`required: false` を使うと argument をオプショナルにできます:

```ruby
# This will be `since: DateTime` instead of `since: DateTime!`
argument :since, Types::DateTime, required: false
```

`required: false` がない場合、`since:` に値がないクエリは拒否されます。
---
title: Changesetsのリリース
description: 変更をバージョン番号に関連付ける
sidebar:
  order: 3
enterprise: true
---
クライアントから利用できるようにするには、`use GraphQL::Enterprise::Changeset::Release changesets_dir: "..."` を使って schema に Changesets を追加します:

```ruby
class MyAppSchema < GraphQL::Schema
  # Add this before root types so that newly-added types are also added to the schema
  use GraphQL::Enterprise::Changeset::Release, changesets_dir: "app/graphql/changesets"

  query(...)
  mutation(...)
  subscription(...)
end
```

これは `app/graphql/changesets/*.rb` に定義された各 Changeset を schema に関連付けます。（Rails の慣習を想定しており、`app/graphql/changesets/add_some_feature.rb` のようなスネークケースのファイルには `Changesets::AddSomeFeature` のようなクラスが含まれていることを前提としています。）

{% callout warning %}

ルートの `query(...)`、`mutation(...)`、`subscription(...)` の設定を行う前に `GraphQL::Enterprise::Changeset::Release` を追加してください。そうしないと、新しい schema バージョン内の型へのリンクがスキーマで見つからない可能性があります。

{% endcallout %}

あるいは、`changesets: [...]` を使って Changesets を明示的に関連付けることもできます。例えば:

```ruby
class MyAppSchema < GraphQL::Schema
  use GraphQL::Enterprise::Changeset::Release, changesets: [
    Changesets::DeprecateRecipeFlag,
    Changesets::RemoveRecipeFlag,
  ]
  # ...
end
```

ディレクトリ内（または配列内）の Changesets のみがクライアントに表示されます。changeset 内の `release ...` 設定は `context[:changeset_version]` と比較され、現在のリクエストにその changeset が適用されるかどうかを判定します。

## リリースの確認

リリースをプレビューするには、[`Schema.to_definition`](https://graphql-ruby.org/api-doc/Schema.to_definition) に `context: { changeset_version: ... }` を渡して schema ダンプを作成できます。

例えば、`API-Version: 2021-06-01` の場合の schema を確認するには:

```ruby
schema_sdl = MyAppSchema.to_definition(context: { changeset_version: "2021-06-01"})
# The GraphQL schema definition for the schema at version "2021-06-01":
puts schema_sdl
```

schema のバージョンが予期せず変わらないようにするには、[スキーマ構造ガイド](/testing/schema_structure) で説明されている手法を利用してください。

### インスペクションメソッド

プログラムから schema の Changesets を確認することもできます。`GraphQL::Enterprise` は `Schema.changesets` メソッドを追加し、changeset クラスの `Set` を返します:

```ruby
MySchema.changesets
# #<Set: {AddNewFeature, RemoveOldFeature}>
```

また、各 changeset はその変更点を説明する `.changes` メソッドを持っています:

```ruby
AddNewFeature.changes
# [
#   #<GraphQL::Enterprise::Changeset::Change: ...>,
#   #<GraphQL::Enterprise::Changeset::Change: ...>,
#   #<GraphQL::Enterprise::Changeset::Change: ...>,
#   ...
# ]
```

各 `Change` オブジェクトは次に応答します:

- `.member` — 変更された schema の部分を返します
- `.type` — 変更の種類を返します（新しいものが追加された場合は `:addition`、メンバーが削除されるか新しい定義に置き換えられた場合は `:removal`）
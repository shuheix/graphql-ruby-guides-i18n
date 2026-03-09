---
title: 安定した Relation Connections
description: ActiveRecord 向けの高度なページネーション
sidebar:
  order: 4
pro: true
---
`GraphQL::Pro` には、カラム値に基づいて `ActiveRecord::Relation` に対して「安定した」connectionを提供する仕組みが含まれています。ページングの最中にオブジェクトが作成・削除されても、アイテムの一覧が乱されません。

これらの connection 実装はデータベース固有で、`NULL` の扱いに関する適切なクエリを構築できるようになっています。（Postgres は null を他の値より「大きい」と扱う一方で、MySQL と SQLite は null を他の値より「小さい」と扱います。）

## 違い

デフォルトの [`GraphQL::Pagination::ActiveRecordRelationConnection`](https://graphql-ruby.org/api-doc/GraphQL::Pagination::ActiveRecordRelationConnection)（`ActiveRecord::Relation` を GraphQL 用の connection に変換するもの）は、カーソルとしてオフセットを使います。この単純な方法は多くのケースで十分ですが、特定のバグに対して脆弱です。

例えば、10 件ずつの 2 ページ目（`LIMIT 10 OFFSET 10`）を見ているとします。その間に 1 ページ目のアイテムのうちの 1 つが削除されたとします。ページ 3（`LIMIT 10 OFFSET 20`）に移動すると、実際には 1 件のアイテムを「見落とす」ことになります。前のアイテムが削除されたときに、リスト全体が「上」にシフトしてしまうためです。

このバグを解決するには、_offset_ の代わりに値（value）を使ってページングするべきです。例えばアイテムが `id` でソートされているなら、ページングに `id` を使います:

```sql
LIMIT 10                      -- page 1
WHERE id > :last_id LIMIT 10  -- page 2
```

こうすれば、アイテムが追加・削除されても、ページングは中断することなく続行されます。

この問題の詳細については、["Pagination: You're (Probably) Doing It Wrong"](https://coderwall.com/p/lkcaag/pagination-you-re-probably-doing-it-wrong) を参照してください。

## インストール

スキーマレベルでインストールすれば、すべての `ActiveRecord::Relation` に対して安定した connection を使うようにできます:

```ruby
class MyAppSchema < GraphQL::Schema
  # Hook up the stable connection that matches your database
  connections.add(ActiveRecord::Relation, GraphQL::Pro::PostgresStableRelationConnection)
  # Or...
  # connections.add(ActiveRecord::Relation, GraphQL::Pro::MySQLStableRelationConnection)
  # connections.add(ActiveRecord::Relation, GraphQL::Pro::SqliteStableRelationConnection)
end
```

あるいは、フィールド単位で安定した connection ラッパーを適用することもできます。例えば:

```ruby
field :items, Types::ItemType.connection_type, null: false

def items
  # Build an ActiveRecord::Relation
  relation = Item.all
  # And wrap it with a connection implementation, then return the connection
  GraphQL::Pro::MySQLStableRelationConnection.new(relation)
end
```

このようにすれば、安定したカーソルを段階的に導入できます。（下の[下位互換性](#下位互換性)に関する注意を参照してください。）

同様に、スキーマ全体で安定した connection を有効にしている場合でも、インデックスベースのカーソルを使いたい特定の relation については `GraphQL::Pagination::ActiveRecordRelationConnection` でラップすることができます。（カーソル生成が難しいほどソート順が複雑な relation に便利です。）

## 実装上の注意

値ベースのカーソルを使用する際は、以下の点に注意してください:

- 特定の `ActiveRecord::Relation` については、そのモデル固有のカラムのみがページングに使えます。（カラム名が `WHERE` 条件に変換されるためです。）
- connection はカーソル値が一意になるように、追加の `primary_key` による並び順を加えることがあります。この挙動は `Relation#reverse_order` に触発されたもので、`primary_key` をデフォルトのソートと想定しています。
- connection はカーソルを信頼性よく構築できるように、relation の `SELECT` 句にフィールドを追加します。

## グループ化された ActiveRecord::Relation

グループ化された `ActiveRecord::Relation` を使う場合、結果の各行が一意のカーソルを持つように、ソートに一意の ID を含めてください。例えば:

```ruby
# Bad: If two results have the same `max(price)`,
# they will be identical from a pagination perspective:
Products.select("max(price) as price").group("category_id").order("price")

# Good: `category_id` is used to disambiguate any results with the same price:
Products.select("max(price) as price").group("category_id").order("price, category_id")
```

グループ化されていない relation については、モデルの `primary_key` を order 値に自動的に追加することでこの問題は対処されます。

順序付けされていないグループ化された relation を渡した場合、`GraphQL::Pro::RelationConnection::InvalidRelationError` が発生します。順序付けされていない relation は、安定した方法でページングすることができないためです。

## 下位互換性

`GraphQL::Pro` の安定した relation connection は下位互換性があります。オフセットベースのカーソルを受け取った場合は、それを次回の解決で使用し、その後の結果では値ベースのカーソルを返します。

## ActiveRecord のバージョン

Stable relation connections は ActiveRecord `>= 4.1.0` をサポートします。
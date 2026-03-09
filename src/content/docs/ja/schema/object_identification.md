---
title: オブジェクト識別
description: ユニークなグローバルIDの取り扱い
sidebar:
  order: 8
---
GraphQL-Ruby には、[Relay スタイルのオブジェクト識別](https://relay.dev/graphql/objectidentification.htm) を実装するためのヘルパーがいくつか含まれています。

## Schema メソッド

必須のトップレベルフックについては [Schema 定義ガイド](/schema/definition#object-identification) を参照してください。

## Node interface

Relay のオブジェクト管理の要件のひとつは、"Node" interface を実装することです。

Node interface を実装するには、定義に [`GraphQL::Types::Relay::Node`](https://graphql-ruby.org/api-doc/GraphQL::Types::Relay::Node) を追加します:

```ruby
class Types::PostType < GraphQL::Schema::Object
  # Implement the "Node" interface for Relay
  implements GraphQL::Types::Relay::Node
  # ...
end
```

`Node` interface のメンバーをどのように解決するかを GraphQL に伝えるために、`Schema.resolve_type` も定義する必要があります:

```ruby
class MySchema < GraphQL::Schema
  # You'll also need to define `resolve_type` for
  # telling the schema what type Relay `Node` objects are
  def self.resolve_type(type, obj, ctx)
    case obj
    when Post
      Types::PostType
    when Comment
      Types::CommentType
    else
      raise("Unexpected object: #{obj}")
    end
  end
end
```

## UUID fields

Node はグローバルに一意な ID を返す "id" という名前の field を持つ必要があります。

"id" という UUID field を追加するには、[`GraphQL::Types::Relay::Node`](https://graphql-ruby.org/api-doc/GraphQL::Types::Relay::Node) interface を実装します:

```ruby
class Types::PostType < GraphQL::Schema::Object
  implements GraphQL::Types::Relay::Node
end
```

この field は前述の `id_from_object` クラスメソッドを呼び出します。

## `node` field（UUID での検索）

Relay がスキーマからオブジェクトを再取得できるように、ルートレベルの `node` field も提供してください。次のように追加できます:

```ruby
class Types::QueryType < GraphQL::Schema::Object
  # Used by Relay to lookup objects by UUID:
  # Add `node(id: ID!)
  include GraphQL::Types::Relay::HasNodeField
  # ...
end
```

## `nodes` field

ID の一覧からオブジェクトを再取得できるように、ルートレベルの `nodes` field も提供できます:

```ruby
class Types::QueryType < GraphQL::Schema::Object
  # Fetches a list of objects given a list of IDs
  # Add `nodes(ids: [ID!]!)`
  include GraphQL::Types::Relay::HasNodesField
  # ...
end
```
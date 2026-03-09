---
title: Connection の概念
description: Connections の紹介
sidebar:
  order: 1
---
__Connections__ はページネーションのソリューションで、[Relay JS](https://facebook.github.io/relay) から始まりましたが、現在ではほとんどあらゆる GraphQL API で使用されています。

Connections はいくつかの種類のオブジェクトで構成されます:

- `Connection` types は汎用的な型で、ページネーションに関連するメタデータとアイテムへのアクセスを公開します
- `Edge` types も汎用的な型です。親と子の関係を表します（例: `PostEdge` は `Blog` から `Post` へのリンクを表します）
- _nodes_ は実際のリスト項目です。`PostsConnection` では各 node が `Post` です

Connections はオフセットベースのページネーションに比べていくつかの利点があります:

- 関係メタデータのファーストクラスサポート
- cursor 実装により効率的で安定したページネーションをサポートできる

## Connections、Edges、Nodes の概要

Connection ページネーションには、connections、edges、nodes という 3 つのコアオブジェクトがあります。

### Nodes の説明

Nodes はリスト内の項目です。`node` は通常スキーマ内のオブジェクトです。たとえば、`posts` connection の `node` は `Post` です:

```ruby
{
  posts(first: 5) {
    edges {
      node {
        # This is a `Post` object:
        title
        body
        publishedAt
      }
    }
  }
}
```

### Connections の説明

Connections は一対多の関係を「表す」オブジェクトです。リストの _メタデータ_ と _アイテムへのアクセス_ を含みます。

Connections はしばしばオブジェクト型から生成されます。リスト項目（_nodes_）はそのオブジェクト型のメンバーです。Connections は union 型や interface 型から生成することもできます。

##### Connection メタデータ

Connections はリスト全体に関する情報を教えてくれます。たとえば、[total count フィールドを追加すると](type_definitions/extensions#customizing-connections)、件数を教えてくれます:

```ruby
{
  posts {
    # This is a PostsConnection
    totalCount
  }
}
```

##### Connection の項目

Connection のリスト項目は _nodes_ と呼ばれます。一般的に次の 2 通りでアクセスできます:

- edges 経由: `posts { edges { node { ... } } }`
- nodes 経由: `posts { nodes { ... } }`

違いは、`edges { node { ... } }` のほうが関係メタデータを格納する余地がある点です。たとえば、チームのメンバーを列挙する際に、その人がいつチームに参加したかを edge のメタデータとして含めることができます:

```ruby
team {
  members(first: 10) {
    edges {
      # when did this person join the team?
      joinedAt
      # information about the person:
      node {
        name
      }
    }
  }
}
```

あるいは、`nodes` はアイテムに簡単にアクセスできますが、関係メタデータを公開することはできません:

```ruby
team {
  members(first: 10) {
    nodes {
      # shows the team members' names
      name
    }
  }
}
```

上の `joinedAt` を表示する方法は、`edges { ... }` を使わないとありません。

### Edges の説明

Edges は親オブジェクトと子オブジェクトの間の関係に関するメタデータを公開できる点で、結合テーブルのようなものです。

たとえば、ある人が複数のチームのメンバーである場合を考えます。データベース側で（例: `team_memberships`）人とチームをつなぐ結合テーブルを作ります。この結合テーブルには、その人がどのようにチームに関係しているか（いつ参加したか、どんな役割かなど）に関する情報を含めることもできます。

Edges はそのような関係に関する情報を明らかにできます。例えば:

```ruby
team {
  # this is the team name
  name

  members(first: 10) {
    edges {
      # this is a team membership
      joinedAt
      role

      node {
        # this is the person on the team
        name
      }
    }
  }
}
```

つまり、2 つのオブジェクト間の「関係」に特別なデータが紐付いている場合、edges が非常に有用です。結合テーブルを使っているなら、その関係をモデル化するためにカスタムの edge を使うべきだという手がかりになります。
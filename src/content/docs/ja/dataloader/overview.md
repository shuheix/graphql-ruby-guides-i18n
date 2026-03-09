---
title: 概要
description: Fiber ベースの Dataloader の始め方
sidebar:
  order: 0
---
[`GraphQL::Dataloader`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader) は、Ruby の `Fiber` 並行プリミティブをバックエンドに、外部サービスへの効率的なバッチアクセスを提供します。クエリごとの結果キャッシュを備えており、[AsyncDataloader](/dataloader/async_dataloader) はそのままでも真の並列実行をサポートします。

`GraphQL::Dataloader` は [`@bessey` の proof-of-concept](https://github.com/bessey/graphql-fiber-test/tree/no-gem-changes) と [shopify/graphql-batch](https://github.com/shopify/graphql-batch) に触発されています。

## バッチ読み込み

`GraphQL::Dataloader` は、外部ソース（データベースや API など）からデータを取得するための2段階のアプローチを容易にします:

- まず、GraphQL fields がデータ要件（例: オブジェクトIDやクエリパラメータ）を登録します
- その後、可能な限り多くの要件が集められた時点で、`GraphQL::Dataloader` が外部サービスへの実際のフェッチを開始します

このサイクルは実行中に繰り返されます: 実行可能な GraphQL fields がなくなるまでデータ要件が集められ、その要件に基づいて `GraphQL::Dataloader` が外部呼び出しを行い、GraphQL の実行が再開されます。

## Fiber について

`GraphQL::Dataloader` は Ruby の `Fiber` を使用します。`Fiber` は軽量な並行プリミティブで、`Thread` の内部でアプリケーションレベルのスケジューリングをサポートします。`Fiber` を使うことで、データが要求されたときに GraphQL 実行を一時停止し、データ取得後に実行を再開できます。

高レベルでは、`GraphQL::Dataloader` における `Fiber` の利用は次のようになります:

- GraphQL の実行は Fiber の内部で行われます。
- その Fiber が戻るとき、その Fiber がデータ待ちで一時停止していた場合、GraphQL の実行は新しい Fiber の内部で（兄弟となる）次の GraphQL field から再開します。
- そのサイクルは、さらに兄弟フィールドが存在せず、すべての既知の Fibers が一時停止するまで続きます。
- `GraphQL::Dataloader` は最初に一時停止した Fiber を取り出してそれを再開し、これにより `GraphQL::Dataloader::Source` が `#fetch(...)` 呼び出しを実行します。その Fiber は可能な限り先へ進みます。
- 同様に、一時停止している Fiber が再開され、GraphQL の実行が続行され、すべての一時停止中の Fiber が完全に評価されるまで続きます。

`GraphQL::Dataloader` が新しい `Fiber` を作成するたびに、`Thread.current[...]` から各ペアをコピーして新しい `Fiber` 内に再割り当てします。

`AsyncDataloader` は [`async` gem](https://github.com/socketry/async) の上に構築されており、Ruby のノンブロッキングな `Fiber.schedule` API を通じてネットワークやデータベース通信などの並列 I/O 操作をサポートします。 [詳細 →](/dataloader/async_dataloader)

## はじめに

[`GraphQL::Dataloader`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader) をインストールするには、スキーマで `use ...` を使って追加します。例えば:

```ruby
class MySchema < GraphQL::Schema
  # ...
  use GraphQL::Dataloader
end
```

その後、スキーマ内で `dataloader.with(...).load(...)` を使ってルックアップキーでバッチロードされたオブジェクトを要求できます:

```ruby
field :user, Types::User do
  argument :handle, String
end

def user(handle:)
  dataloader.with(Sources::UserByHandle).load(handle)
end
```

あるいは、ルックアップキーの配列を `.load_all(...)` に渡して複数のオブジェクトをロードできます:

```ruby
field :is_following, Boolean, null: false do
  argument :follower_handle, String
  argument :followed_handle, String
end

def is_following(follower_handle:, followed_handle:)
  follower, followed = dataloader
    .with(Sources::UserByHandle)
    .load_all([follower_handle, followed_handle])

  followed && follower && follower.follows?(followed)
end
```

複数のソースからのリクエストを準備するには `.request(...)` を使い、すべてのリクエストが登録された後で `.load` を呼び出してください:

```ruby
class AddToList < GraphQL::Schema::Mutation
  argument :handle, String
  argument :list, String, as: :list_name

  field :list, Types::UserList

  def resolve(handle:, list_name:)
    # first, register the requests:
    user_request = dataloader.with(Sources::UserByHandle).request(handle)
    list_request = dataloader.with(Sources::ListByName, context[:viewer]).request(list_name)
    # then, use `.load` to wait for the external call and return the object:
    user = user_request.load
    list = list_request.load
    # Now, all objects are ready.
    list.add_user!(user)
    { list: list }
  end
end
```

### `loads:` と `object_from_id`

`dataloader` は `context.dataloader` としても利用できるので、`MySchema.object_from_id` の実装に使うことができます。例えば:

```ruby
class MySchema < GraphQL::Schema
  def self.object_from_id(id, ctx)
    model_class, database_id = IdDecoder.decode(id)
    ctx.dataloader.with(Sources::RecordById, model_class).load(database_id)
  end
end
```

すると、`loads:` を持つ引数はそのメソッドを使ってオブジェクトを取得します。例えば:

```ruby
class FollowUser < GraphQL::Schema::Mutation
  argument :follow_id, ID, loads: Types::User

  field :followed, Types::User

  def resolve(follow:)
    # `follow` was fetched using the Schema's `object_from_id` hook
    context[:viewer].follow!(follow)
    { followed: follow }
  end
end
```

## データソース

バッチ読み込み用のデータソースを実装する方法については、[Sources ガイド](/dataloader/sources) を参照してください。

## 並列実行

`GraphQL::Dataloader` では I/O 操作を並列で実行できます。方法は2つあります:

- `AsyncDataloader` は `async` gem を使って `Dataloader::Source#fetch` 呼び出しから自動的にバックグラウンド I/O を行います。 [詳しく →](/dataloader/async_dataloader)
- バックグラウンドで作業を開始した後に手動で `dataloader.yield` を呼ぶこともできます。 [詳しく →](/dataloader/parallelism)
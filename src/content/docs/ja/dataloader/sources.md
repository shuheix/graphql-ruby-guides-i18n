---
title: Sources
description: GraphQL::Dataloader のオブジェクトをバッチロードする
sidebar:
  order: 1
---
_Sources_ は、[`GraphQL::Dataloader`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader) が外部サービスからデータを取得するために使うものです。

## Source の概念

Sources は `GraphQL::Dataloader::Source` を継承するクラスです。Source は必ず `def fetch(keys)` を実装して、与えられた各キーに対応するオブジェクトの一覧を返す必要があります。必要に応じて `def initialize(...)` を実装して、他のバッチパラメータを受け取ることができます。

Sources は `GraphQL::Dataloader` から次の2種類の入力を受け取ります:

- _keys_ — アプリケーションが要求するオブジェクトに対応するキーです。

  Keys は `def fetch(keys)` に渡され、`keys` と同じ順序で、各キーに対してオブジェクト（または `nil`）を返さなければなりません。

  内部的には、各 Source インスタンスは `key => object` のキャッシュを維持します。

- _batch parameters_ — バッチ化されたグループの基準となるパラメータです。例えば、異なるデータベーステーブルからレコードをロードする場合、テーブル名が batch parameter になります。

  Batch parameters は `dataloader.with(source_class, *batch_parameters)` に渡され、デフォルトは _no batch parameters_ です。Source を定義する際には、`def initialize(...)` に batch parameters を追加し、インスタンス変数に保存してください。

  (`dataloader.with(source_class, *batch_parameters)` は与えられた batch parameters で初期化された `source_class` のインスタンスを返します — ただしそれは `dataloader` によってキャッシュされているインスタンスかもしれません。)

  さらに、batch parameters はクエリ実行中の Source 初期化の重複排除にも使われます。同じ batch parameters で行われた `.with(...)` の呼び出しは、内部的に同じ Source インスタンスを使用します。Source の重複排除のカスタマイズ方法は、[`GraphQL::Dataloader::Source.batch_key_for`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader::Source.batch_key_for) を参照してください。

## 例: Redis からキーで文字列をロードする

最も単純な source はキーに基づいて値を取得するものです。例えば:

```ruby
# app/graphql/sources/redis_string.rb
class Sources::RedisString < GraphQL::Dataloader::Source
  REDIS = Redis.new
  def fetch(keys)
    # Redis's `mget` will return a value for each key with a `nil` for any not-found key.
    REDIS.mget(*keys)
  end
end
```

この loader は GraphQL 内で次のように使えます:

```ruby
some_string = dataloader.with(Sources::RedisString).load("some_key")
```

`.load(key)` の呼び出しはバッチ化され、`GraphQL::Dataloader` が先に進めなくなった時点で上記の `def fetch(keys)` がディスパッチされます。

## 例: ID による ActiveRecord オブジェクトのロード

ID によって ActiveRecord オブジェクトを取得するには、source は _model class_ をバッチパラメータとして受け取るべきです。例えば:

```ruby
# app/graphql/sources/active_record_object.rb
class Sources::ActiveRecordObject < GraphQL::Dataloader::Source
  def initialize(model_class)
    @model_class = model_class
  end

  def fetch(ids)
    records = @model_class.where(id: ids)
    # return a list with `nil` for any ID that wasn't found
    ids.map { |id| records.find { |r| r.id == id.to_i } }
  end
end
```

この source は任意の `model_class` に対して使えます。例えば:

```ruby
author = dataloader.with(Sources::ActiveRecordObject, ::User).load(1)
post = dataloader.with(Sources::ActiveRecordObject, ::Post).load(1)
```

## 例: バッチ化された計算

オブジェクトの取得以外に、Sources はバッチ化された計算の結果を返すこともできます。例えば、あるユーザーが別のユーザーをフォローしているかどうかをバッチチェックするシステム:

```ruby
# for a given user, batch checks to see whether this user follows another user.
# (The default `user.followings.where(followed_user_id: followed).exists?` would cause N+1 queries.)
class Sources::UserFollowingExists < GraphQL::Dataloader::Source
  def initialize(user)
    @user = user
  end

  def fetch(handles)
    # Prepare a `SELECT id FROM users WHERE handle IN(...)` statement
    user_ids = ::User.where(handle: handles).select(:id)
    # And use it to filter this user's followings:
    followings = @user.followings.where(followed_user_id: user_ids)
    # Now, for followings that _actually_ hit a user, get the handles for those users:
    followed_users = ::User.where(id: followings.select(:followed_user_id))
    # Finally, return a result set, with one entry (true or false) for each of the given `handles`
    handles.map { |h| !!followed_users.find { |u| u.handle == h }}
  end
end
```

使用例:

```ruby
is_following = dataloader.with(Sources::UserFollowingExists, context[:viewer]).load(handle)
```

すべてのリクエストがバッチ化された後、`#fetch` は `is_following` に対して Boolean の結果を返します。

## 例: バックグラウンドスレッドでのロード

`Source#fetch(keys)` の中で `dataloader.yield` を呼ぶと、Dataloader に制御を返すことができます。こうすることで、他の Sources の読み込み（存在する場合）を進め、その後に yield した source に戻ってくる、という動作になります。

新しい Thread を立ち上げる単純な例:

```ruby
def fetch(keys)
  # spin up some work in a background thread
  thread = Thread.new {
    fetch_external_data(keys)
  }
  # return control to the dataloader
  dataloader.yield
  # at this point,
  # the dataloader has tried everything else and come back to this source,
  # so block if necessary:
  thread.value
end
```

このアプローチの詳細は、[並列実行ガイド](/dataloader/parallelism) を参照してください。

## Dataloader のキャッシュを埋める

データベースからレコードをロードする場合、[`Dataloader::Source#merge`](https://graphql-ruby.org/api-doc/Dataloader::Source#merge) を使って source のキャッシュを事前に埋めることができます。例えば:

```ruby
# Build a `{ key => value }` map to populate the cache
comments_by_id = post.comments.each_with_object({}) { |comment, hash| hash[comment.id] = comment }
# Merge the map into the source's cache
dataloader.with(Sources::ActiveRecordObject, Comment).merge(comments_by_id)
```

これを行うと、利用可能な既にロード済みのレコードがあれば、その後の `.load(id)` の呼び出しでそれらが使われます。

## 等価なオブジェクトの重複排除

アプリケーション内で、異なるオブジェクトが同じ `fetch` から同一のオブジェクトをロードすべき場合があります。この挙動は `def result_key_for(key)` を実装してカスタマイズできます。例えば、ORM のレコードをデータベース ID にマップして重複排除するには:

```ruby
# Load the `created_by` person for a record from our database
class CreatedBySource < GraphQL::Dataloader::Source
  def result_key_for(key)
    key.id # Use the record's ID to deduplicate different `.load` calls
  end

  # Fetch a `person` for each of `records`, based on their created_by_id
  def fetch(records)
    PersonService.find_each(records.map(&:created_by_id))
  end
end
```

この場合、`records` には各一意な `record.id` に対する最初のオブジェクトが含まれます — 同じ `.id` を持つ後続のレコードは重複と見なされます。内部的には、Source はレコードの `id` に基づいて結果をキャッシュします。

あるいは、通常は重複と見なされる場合でも、Source が入力された各オブジェクトを保持するようにすることもできます（たとえば `def fetch` が各オブジェクトを mutate する必要がある場合など）。すべての入力オブジェクトを個別に扱う例:

```ruby
def result_key_for(record)
  record.object_id # even if the records are equivalent, handle each distinct Ruby object separately
end
```
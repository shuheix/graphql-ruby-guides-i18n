---
title: Subscription クラス
description: クライアントに更新をプッシュするための Subscription resolver
sidebar:
  order: 1
---
サブスクライブ可能な fields を作成するために、[`GraphQL::Schema::Subscription`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Subscription) を継承できます。

これらのクラスは次のような振る舞いをサポートします。

- [認可](#check-permissions-with-authorized)（最初のサブスクリプション要求や後続の更新を拒否する）
- [初回 subscription リクエスト](#initial-subscription-with-subscribe) に対する値の返却
- サーバーからの [購読解除](#terminating-the-subscription-with-unsubscribe)
- 更新を適切な購読者に届けるための暗黙の [更新のスコープ設定](#scope)
- 特定のクライアント向けに [更新をスキップ](#subsequent-updates-with-update) する（例: イベントを発火させた本人には送らない）

以下では subscription クラスのセットアップ方法を説明します。

## ベースクラスを追加する

まず、アプリケーション用のベースクラスを追加します。ここでベースクラスを接続できます:

```ruby
# app/graphql/subscriptions/base_subscription.rb
class Subscriptions::BaseSubscription < GraphQL::Schema::Subscription
  # Hook up base classes
  object_class Types::BaseObject
  field_class Types::BaseField
  argument_class Types::BaseArgument
end
```

（このベースクラスは [mutation ベースクラス](/mutations/mutation_classes) に非常によく似ています。どちらも [`GraphQL::Schema::Resolver`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Resolver) のサブクラスです。）

## ベースクラスを拡張して接続する

システム内で購読可能なイベントごとにクラスを定義します。例えばチャットルームを運用している場合、部屋にメッセージが投稿されるたびにイベントを publish するようにできます:

```ruby
# app/graphql/subscriptions/message_was_posted.rb
class Subscriptions::MessageWasPosted < Subscriptions::BaseSubscription
end
```

次に、新しいクラスを [Subscription ルート type](subscriptions/subscription_type) に `subscription:` オプションで紐付けます:

```ruby
class Types::SubscriptionType < Types::BaseObject
  field :message_was_posted, subscription: Subscriptions::MessageWasPosted
end
```

これで、次のようにアクセスできるようになります:

```graphql
subscription {
  messageWasPosted(roomId: "abcd") {
    # ...
  }
}
```

## 引数

Subscription fields は通常の fields と同様に [arguments](/fields/arguments) を受け取ります。mutations と同様に [`loads:` オプション](/mutations/mutation_classes#auto-loading-arguments) も使えます。例えば:

```ruby
class Subscriptions::MessageWasPosted < Subscriptions::BaseSubscription
  # `room_id` loads a `room`
  argument :room_id, ID, loads: Types::RoomType

  # It's passed to other methods as `room`
  def subscribe(room:)
    # ...
  end

  def update(room:)
    # ...
  end
end
```

これは次のように呼ばれます:

```graphql
subscription($roomId: ID!) {
  messageWasPosted(roomId: $roomId) {
    # ...
  }
}
```

ID がオブジェクトを見つけられない場合、subscription は `#unsubscribe` されます（下記参照）。

## フィールド

mutations と同様に、subscription でも生成された return type を使えます。subscription に `field(...)` を追加すると、それらは subscription の生成された return type に追加されます。例えば:

```ruby
class Subscriptions::MessageWasPosted < Subscriptions::BaseSubscription
  field :room, Types::RoomType, null: false
  field :message, Types::MessageType, null: false
end
```

は次のような型を生成します:

```graphql
type MessageWasPostedPayload {
  room: Room!
  message: Message!
}
```

これをクエリで次のように使えます:

```graphql
subscription($roomId: ID!) {
  messageWasPosted(roomId: $roomId) {
    room {
      name
    }
    message {
      author {
        handle
      }
      body
      postedAt
    }
  }
}
```

`null: false` を外すと、初回の subscription とその後の更新で異なるデータを返すことができます（ライフサイクルメソッドを参照してください）。

生成型の代わりに、既に構成された型を `payload_type` で指定することもできます:

```ruby
# Just return a message
payload_type Types::MessageType
```

（その場合、`#subscribe` や `#update` からハッシュを返すのではなく、`message` オブジェクト自体を返してください。）

## スコープ

通常、GraphQL-Ruby は明示的に渡された引数を使っていつ [trigger](subscriptions/triggers) がアクティブな subscription に適用されるかを判断します。しかし、`subscription_scope` を使うと更新に対する暗黙の条件を設定できます。`subscription_scope` が設定されていると、送信された `scope:` 値が一致する trigger のみがクライアントに更新を送ります。

`subscription_scope` はシンボルを受け取り、そのシンボルは `context` で参照されてスコープ値を取得します。

例えば、次の subscription は `context[:current_organization_id]` をスコープとして使用します:

```ruby
class Subscriptions::EmployeeHired < Subscriptions::BaseSubscription
  # ...
  subscription_scope :current_organization_id
end
```

クライアントは引数なしで購読します:

```graphql
subscription {
  employeeHired {
    hireDate
    employee {
      name
      department
    }
  }
}
```

しかし `.trigger` は `scope:` を使ってルーティングされます。したがって、購読者の context に `current_organization_id: 100` が含まれている場合、trigger は同じ `scope:` 値を含める必要があります:

```ruby
MyAppSchema.subscriptions.trigger(
  # Field name
  :employee_hired,
  # Arguments
  {},
  # Object
  { hire_date: Time.now, employee: new_employee },
  # This corresponds to `context[:current_organization_id]`
  # in the original subscription:
  scope: 100
 )
```

スコープは、購読者が同じ [broadcast](subscriptions/implementation#broadcast) を受け取れるかどうかを判定する際にも使われます。

## #authorized? で権限を確認する

クライアントがチャットルームのメッセージを購読しているとします:

```graphql
subscription($roomId: ID!) {
  messageWasPosted(roomId: $roomId) {
    message {
      author { handle }
      body
      postedAt
    }
  }
}
```

`#authorized?` を実装して、ユーザーがこれらの引数に対して購読（およびこれらの引数に対する更新を受け取る）権限を持っているかを確認できます。例:

```ruby
def authorized?(room:)
  super && context[:viewer].can_read_messages?(room)
end
```

このメソッドは `false` を返すか、`GraphQL::ExecutionError` を発生させて実行を停止できます。

このメソッドは `#subscribe` と `#update` よりも先に呼び出されます。これにより、ユーザーの権限が購読登録後に変更されていた場合でも、不正な更新を受け取らないようにできます。

また、このメソッドが `#update` の前に失敗した場合、クライアントは自動的に `#unsubscribe` されます。

## 初回購読と #subscribe

`def subscribe(**args)` はクライアントが初めて `subscription { ... }` リクエストを送信したときに呼ばれます。このメソッドでは次のことができます:

- `GraphQL::ExecutionError` を発生させて処理を停止しエラーを返す
- 値を返してクライアントに初回レスポンスを与える
- `:no_response` を返して初回レスポンスをスキップする
- `super` を返してデフォルト動作（` :no_response`）にフォールバックする

初回レスポンスを追加したり、購読前に他のロジックを実行するためにこのメソッドを定義できます。

### 初回レスポンスを追加する

デフォルトでは、GraphQL-Ruby は初回の subscription で何も返しません（`:no_response`）。しかし、`def subscribe` をオーバーライドして初回に値を返すこともできます。例えば:

```ruby
class Subscriptions::MessageWasPosted < Subscriptions::BaseSubscription
  # ...
  field :room, Types::RoomType

  def subscribe(room:)
    # authorize, etc ...
    # Return the room in the initial response
    {
      room: room
    }
  end
end
```

これにより、クライアントは初期データを取得できます:

```graphql
subscription($roomId: ID!) {
  messageWasPosted(roomId: $roomId) {
    room {
      name
      messages(last: 40) {
        # ...
      }
    }
  }
}
```

## 続く更新と #update

クライアントが購読登録を行った後、アプリケーションは `MySchema.subscriptions.trigger(...)` で subscription の更新を発火できます（詳細は [Triggers ガイド](/subscriptions/triggers) を参照してください）。そのとき、各クライアントの subscription に対して `def update` が呼ばれます。このメソッドでは次のことができます:

- `unsubscribe` を呼んでクライアントを購読解除する
- `super`（`object` を返す）もしくは別の値を返して値を返却する
- `NO_UPDATE` を返してこの更新をスキップする

### 購読更新をスキップする

特定の購読者に更新を送信したくない場合があります。例えば、誰かがコメントを投稿した場合、投稿者自身にはそのコメントデータが既にあるので、他の購読者にだけ新しいコメントをプッシュしたいことがあります。これには `NO_UPDATE` を返します。

```ruby
class Subscriptions::CommentWasAdded < Subscriptions::BaseSubscription
  def update(post_id:)
    comment = object # #<Comment ...>
    if comment.author == context[:viewer]
      NO_UPDATE
    else
      # Continue updating this client, since it's not the commenter
      super
    end
  end
end
```

### subscription 更新で別のオブジェクトを返す

デフォルトでは、`.trigger(event_name, args, object)` に渡したオブジェクトが subscription フィールドに対する応答に使われます。しかし、`#update` から別のオブジェクトを返してこれをオーバーライドすることもできます:

```ruby
field :queue, Types::QueueType, null: false

# eg, `MySchema.subscriptions.trigger("queueWasUpdated", {name: "low-priority"}, :low_priority)`
def update(name:)
  # Make a Queue object which _represents_ the queue with this name
  queue = JobQueue.new(name)

  # This object was passed to `.trigger`, but we're ignoring it:
  object # => :low_priority

  # return the queue instead:
  { queue: queue }
end
```

## #unsubscribe で購読を終了する

サブスクリプションメソッド内で `unsubscribe` を呼んでクライアントの購読を終了できます。例えば:

```ruby
def update(room:)
  if room.archived?
    # Don't let anyone subscribe to messages on an archived room
    unsubscribe
  else
    super
  end
end
```

`#unsubscribe` の効果は次の通りです:

- サブスクリプションはバックエンドから登録解除されます（バックエンド依存）
- クライアントに購読解除が通知されます（トランスポート依存）

`loads:` 設定のある引数は、`required: true`（デフォルト）の場合、ID が値を返さないと `unsubscribe` を呼び出します（購読対象のオブジェクトが削除されたと想定されます）。

`unsubscribe` に値を渡すことで最終的な更新値を提供することもできます:

```ruby
def update(room:)
  if room.archived?
    # Don't let anyone subscribe to messages on an archived room
    unsubscribe({message: "This room has been archived"})
  else
    super
  end
end
```

## 追加情報

Subscription メソッドはクラス定義内で `extras [...]` を設定することでクエリ関連のメタデータにアクセスできます。例えば、`lookahead` と `ast_node` を使うには:

```ruby
class Subscriptions::JobFinished < GraphQL::Schema::Subscription
  # ...
  extras [:lookahead, :ast_node]

  def subscribe(lookahead:, ast_node:)
    # ...
  end

  def update(lookahead:, ast_node:)
    # ...
  end
end
```

利用可能なメタデータの詳細は [追加の Field メタデータ](/fields/introduction#extra-field-metadata) を参照してください。
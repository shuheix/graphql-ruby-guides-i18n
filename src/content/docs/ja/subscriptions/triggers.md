---
title: トリガー
description: アプリケーションからGraphQLクライアントへ更新を送信する
sidebar:
  order: 2
---
アプリケーションから、`.trigger` を使って GraphQL クライアントに更新をプッシュできます。

イベントは名前（_by name_）でトリガーされ、名前は [Subscription Type](subscriptions/subscription_type) の fields と一致している必要があります。

```ruby
# Update the system with the new blog post:
MySchema.subscriptions.trigger(:post_added, {}, new_post)
```

引数は次のとおりです:

- `name`、subscription type 上の field に対応します
- `arguments`、subscription type 上の arguments に対応します（たとえば特定の投稿のコメントを購読している場合、arguments は `{post_id: comment.post_id}` のようになります）
- `object`、subscription 更新のルートオブジェクトになります
- `scope:`（以下で説明）— 更新を受け取るクライアントを暗黙的にスコープするためのものです

## スコープ

特定のクライアントのみに更新を送信したい場合は、`scope:` を使ってトリガーの到達範囲を絞れます。

スコープはクエリの context に基づきます: `context:` にある値がスコープとして使われ、同等の値を `.trigger(... scope:)` に渡す必要があります。（その値は [`GraphQL::Subscriptions::Serialize`](https://graphql-ruby.org/api-doc/GraphQL::Subscriptions::Serialize) でシリアライズされます）

トピックがスコープ付きであることを指定するには、Subscription クラスに `subscription_scope` オプションを追加します:

```ruby
class Subscriptions::CommentAdded < Subscription::BaseSubscription
  description "A comment was added to one of the viewer's posts"
  # For a given viewer, this will be triggered
  # whenever one of their posts gets a new comment
  subscription_scope :current_user_id
  # ...
end
```

（詳しくは [Subscription Classes ガイド](subscriptions/subscription_classes#scope) を参照してください。）

その後、subscription の操作は `context: { current_user_id: ... }` の値を持つ必要があります。たとえば:

```ruby
# current_user_id will be the scope for some subscriptions:
MySchema.execute(query_string, context: { current_user_id: current_user.id })
```

最後に、アプリでイベントが発生したときはスコーピング値を `scope:` として渡します。たとえば:

```ruby
# A new comment is added
comment = post.comments.create!(attrs)
# notify the author
author_id = post.author.id
MySchema.subscriptions.trigger(:comment_added, {}, comment, scope: author_id)
```

このトリガーが `scope:` を持つため、対応する scope 値を持つ購読者のみが更新されます。

## 検証

デフォルトでは、トリガーによって更新が送信される際に subscriptions は再検証されます。これを無効にするには、subscriptions を schema に接続するときに `validate_update: false` を渡します。たとえば:

```ruby
use SomeSubscriptions, validate_update: false
```

schema に破壊的な変更を加える予定がないと確信できる場合、この設定により更新の評価にかかるオーバーヘッドを減らせます。
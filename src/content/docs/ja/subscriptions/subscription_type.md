---
title: Subscription Type
description: subscriptions のルート type
sidebar:
  order: 1
---
`Subscription` は GraphQL システムにおけるすべての subscriptions のエントリポイントです。各 field はサブスクライブ可能なイベントに対応します:

```graphql
type Subscription {
  # Triggered whenever a post is added
  postWasPublished: Post
  # Triggered whenever a comment is added;
  # to watch a certain post, provide a `postId`
  commentWasPublished(postId: ID): Comment
}
```

この type は `subscription` 操作のルートです。例えば:

```graphql
subscription {
  postWasPublished {
    # This data will be delivered whenever `postWasPublished`
    # is triggered by the server:
    title
    author {
      name
    }
  }
}
```

システムに subscriptions を追加するには、`Subscription` という名前の `ObjectType` を定義します:

```ruby
# app/graphql/types/subscription_type.rb
class Types::SubscriptionType < GraphQL::Schema::Object
  field :post_was_published, subscription: Subscriptions::PostWasPublished
  # ...
end
```

次に、`subscription(...)` でそれを subscription ルートとして追加します:

```ruby
# app/graphql/my_schema.rb
class MySchema < GraphQL::Schema
  query(Types::QueryType)
  # ...
  # Add Subscription to
  subscription(Types::SubscriptionType)
end
```

実際の更新の配信については [Subscriptions の実装](subscriptions/implementation) を参照してください。

subscription root field の実装については [Subscription クラス](subscriptions/subscription_classes) を参照してください。
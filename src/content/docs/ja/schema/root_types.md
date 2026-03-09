---
title: ルート types
description: ルート types は query、mutation、subscription のエントリポイントです。
sidebar:
  order: 2
---
GraphQL のクエリは [ルート types](https://graphql.org/learn/schema/#the-query-mutation-and-subscription-types) から始まります: `query`、`mutation`、そして `subscription`。

これらを schema に同名のメソッドでスキーマに設定します:

```ruby
class MySchema < GraphQL::Schema
  # required
  query Types::QueryType
  # optional
  mutation Types::MutationType
  subscription Types::SubscriptionType
end
```

それらの type は `GraphQL::Schema::Object` クラスです。例えば:

```ruby
# app/graphql/types/query_type.rb
class Types::QueryType < GraphQL::Schema::Object
  field :posts, [PostType], 'Returns all blog posts', null: false
end

# Similarly:
class Types::MutationType < GraphQL::Schema::Object
  field :create_post, mutation: Mutations::AddPost
end
# and
class Types::SubscriptionType < GraphQL::Schema::Object
  field :comment_added, subscription: Subscriptions::CommentAdded
end
```

各 type は対応する GraphQL の query に対するエントリポイントです:

```ruby
query Posts {
  # `Query.posts`
  posts { ... }
}

mutation AddPost($postAttrs: PostInput!){
  # `Mutation.createPost`
  createPost(attrs: $postAttrs)
}

subscription CommentAdded {
  # `Subscription.commentAdded`
  commentAdded(postId: 1)
}
```
---
title: ミューテーションのエラー
description: ミューテーションからのエラーを処理して返すためのヒント
sidebar:
  order: 2
---
mutation内でエラーをどのように扱いますか？いくつかの方法を見てみます。

## エラーを発生させる

エラーを扱う一つの方法は、例えば次のようにraiseすることです:

```ruby
def resolve(id:, attributes:)
  # Will crash the query if the data is invalid:
  Post.find(id).update!(attributes.to_h)
  # ...
end
```

または:

```ruby
def resolve(id:, attributes:)
  if post.update(attributes)
    { post: post }
  else
    raise GraphQL::ExecutionError, post.errors.full_messages.join(", ")
  end
end
```

このようなエラー処理はエラー状態を表現します（`HTTP 500` またはトップレベルの `"errors"` キーを通じて）が、GraphQLのtypeシステムを活用しておらず、一度に一つのエラーしか表現できません。動作はしますが、より良い方法はエラーをデータとして扱うことです。

## エラーをデータとして扱う

より詳細なエラー情報を扱う別の方法は、schemaにエラー用のtypeを追加することです。例えば:

```ruby
class Types::UserError < Types::BaseObject
  description "A user-readable error"

  field :message, String, null: false,
    description: "A description of the error"
  field :path, [String],
    description: "Which input value this error came from"
end
```

そして、mutationにこのエラーtypeを使うfieldを追加します:

```ruby
class Mutations::UpdatePost < Mutations::BaseMutation
  # ...
  field :errors, [Types::UserError], null: false
end
```

mutationの`resolve`メソッド内では、ハッシュに必ず`errors:`を返すようにします:

```ruby
def resolve(id:, attributes:)
  post = Post.find(id)
  if post.update(attributes)
    {
      post: post,
      errors: [],
    }
  else
    # Convert Rails model errors into GraphQL-ready error hashes
    user_errors = post.errors.map do |error|
      # This is the GraphQL argument which corresponds to the validation error:
      path = ["attributes", error.attribute.to_s.camelize(:lower)]
      {
        path: path,
        message: error.message,
      }
    end
    {
      post: post,
      errors: user_errors,
    }
  end
end
```

これで、payloadのfieldが`errors`を返すようになるため、例えば次のようにmutationのレスポンス内で`errors`を扱えます:

```graphql
mutation($postId: ID!, $postAttributes: PostAttributes!) {
  updatePost(id: $postId, attributes: $postAttributes) {
    # This will be present in case of success or failure:
    post {
      title
      comments {
        body
      }
    }
    # In case of failure, there will be errors in this list:
    errors {
      path
      message
    }
  }
}
```

失敗した場合、次のようなレスポンスが返ることがあります:

```ruby
{
  "data" => {
    "createPost" => {
      "post" => nil,
      "errors" => [
        { "message" => "Title can't be blank", "path" => ["attributes", "title"] },
        { "message" => "Body can't be blank", "path" => ["attributes", "body"] }
      ]
    }
  }
}
```

クライアントアプリはこのエラーメッセージをエンドユーザーに表示できるため、例えばフォームのどのフィールドを修正すべきかを示すことができます。

## ヌル許容のミューテーション・ペイロードフィールド

上で説明した「エラーをデータとして扱う」を活かすには、mutationのfieldが`null: false`になっていてはなりません。なぜでしょうか？

非nullフィールド（`null: false`を持つ）では、もし`nil`を返すと、GraphQLはクエリを中断し、そのフィールドをレスポンスから丸ごと削除してしまいます。

mutationではエラーが発生したとき、他のフィールドが`nil`を返すことがあります。もしそれらのフィールドが`null: false`で、`nil`を返すと、GraphQLはパニックになり、mutation全体（`errors`を含む）をレスポンスから削除してしまいます。

他のフィールドが`nil`のときでも詳細なエラー情報を返すには、それらのフィールドは`null: true`（デフォルト）にしておく必要があります。そうすることで、エラー発生時でもtypeシステム（type system）を満たすことができます。

例（ヌル許容で良い例）:

```ruby
class Mutations::UpdatePost < Mutations::BaseMutation
  # Use the default `null: true` to support rich errors:
  field :post, Types::Post
  # ...
end
```
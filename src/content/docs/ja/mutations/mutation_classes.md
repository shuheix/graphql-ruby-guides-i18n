---
title: Mutation クラス
description: mutation クラスを用いて振る舞いを実装し、それを schema に接続します。
sidebar:
  order: 1
redirect_from:
- "/queries/mutations/"
- "/relay/mutations/"
---
GraphQL の mutation は特殊な field です。データの読み取りや計算を行う代わりに、アプリケーションの状態を変更することがあります。例えば、mutation field は次のような操作を行います:

- データベースのレコードを作成、更新、削除する
- 既存のレコード同士の関連付けを確立する
- カウンタを増加させる
- ファイルを作成、変更、削除する
- キャッシュをクリアする

これらの操作は「副作用」と呼ばれます。

すべての GraphQL field と同様に、mutation field は次のことを行います:

- 入力（argument と呼ばれる）を受け取る
- field を通じて値を返す

GraphQL-Ruby には mutation を書くのに役立つ 2 つのクラスがあります:

- [`GraphQL::Schema::Mutation`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Mutation), a bare-bones base class
- [`GraphQL::Schema::RelayClassicMutation`](https://graphql-ruby.org/api-doc/GraphQL::Schema::RelayClassicMutation), a base class with a set of nice conventions that also supports the Relay Classic mutation specification.

それらのほかに、プレーンな [field API](/type_definitions/objects#fields) を使って mutation field を書くこともできます。

例: Mutation クラス

もし [install ジェネレータ](/schema/generators#graphqlinstall) を使った場合は、既に base mutation クラスが生成されているはずです。そうでない場合は、アプリケーションに base クラスを追加してください。例えば:

```ruby
class Mutations::BaseMutation < GraphQL::Schema::RelayClassicMutation
  # Add your custom classes if you have them:
  # This is used for generating payload types
  object_class Types::BaseObject
  # This is used for return fields on the mutation's payload
  field_class Types::BaseField
  # This is used for generating the `input: { ... }` object type
  input_object_class Types::BaseInputObject
end
```

その上で、各 mutation を拡張します:

```ruby
class Mutations::CreateComment < Mutations::BaseMutation
  null true
  argument :body, String
  argument :post_id, ID

  field :comment, Types::Comment
  field :errors, [String], null: false

  def resolve(body:, post_id:)
    post = Post.find(post_id)
    comment = post.comments.build(body: body, author: context[:current_user])
    if comment.save
      # Successful creation, return the created object with no errors
      {
        comment: comment,
        errors: [],
      }
    else
      # Failed save, return the errors to the client
      {
        comment: nil,
        errors: comment.errors.full_messages
      }
    end
  end
end
```

`#resolve` メソッドは、シンボルが `field` 名と一致するハッシュを返す必要があります。

(詳細は [Mutation エラー](/mutations/mutation_errors) を参照してください。)

また、mutation クラスで `null(false)` を設定すると、生成されるペイロードクラスを non-null にできます。

Mutations を接続する

Mutations は `mutation:` キーワードを使って mutation root にアタッチする必要があります。例えば:

```ruby
class Types::Mutation < Types::BaseObject
  field :create_comment, mutation: Mutations::CreateComment
end
```

argument の自動読み込み

ほとんどの場合、GraphQL mutation は与えられたグローバル relay ID に対して動作します。これらのグローバル relay ID からオブジェクトを読み込むには、mutation の resolver に多くの定型コードが必要になることがあります。

代替手段として、argument を定義する際に `loads:` を使う方法があります:

```ruby
class Mutations::AddStar < Mutations::BaseMutation
  argument :post_id, ID, loads: Types::Post

  field :post, Types::Post

  def resolve(post:)
    post.star

    {
      post: post,
    }
  end
end
```

`post_id` argument が `Types::Post` オブジェクト type を `loads:` するよう指定すると、与えられた `post_id` を用いて [`Schema.object_from_id`](/schema/definition.html#object-identification) 経由で `Post` オブジェクトが読み込まれます。

`_id` で終わり `loads:` を使うすべての argument は `_id` サフィックスが削除されます。例えば上の mutation resolver は、`post_id` ではなく読み込まれたオブジェクトを含む `post` argument を受け取ります。

`loads:` オプションは ID のリストにも対応します。例えば:

```ruby
class Mutations::AddStars < Mutations::BaseMutation
  argument :post_ids, [ID], loads: Types::Post

  field :posts, [Types::Post]

  def resolve(posts:)
    posts.map(&:star)

    {
      posts: posts,
    }
  end
end
```

`_ids` で終わり `loads:` を使うすべての argument は `_ids` サフィックスが削除され、名前に `s` が追加されます。例えば上の mutation resolver は、`post_ids` ではなくすべての読み込まれたオブジェクトを含む `posts` argument を受け取ります。

場合によっては、結果の argument 名を制御したいことがあるでしょう。これは `as:` argument を使って行えます。例えば:

```ruby
class Mutations::AddStar < Mutations::BaseMutation
  argument :post_id, ID, loads: Types::Post, as: :something

  field :post, Types::Post

  def resolve(something:)
    something.star

    {
      post: something
    }
  end
end
```

上の例では `loads:` に具体的な type が渡されていますが、抽象的な type（つまり interface や union）にも対応します。

読み込まれたオブジェクトの type を解決する

`loads:` が [`Schema.object_from_id`](https://graphql-ruby.org/api-doc/Schema.object_from_id) からオブジェクトを取得すると、そのオブジェクトは [`Schema.resolve_type`](https://graphql-ruby.org/api-doc/Schema.resolve_type) に渡され、`loads:` で最初に設定したのと同じ type に解決されることが確認されます。

読み込み失敗時の処理

`loads:` がオブジェクトを見つけられなかった場合、または読み込まれたオブジェクトが [`Schema.resolve_type`](https://graphql-ruby.org/api-doc/Schema.resolve_type) を使って指定した `loads:` type に解決されなかった場合、[`GraphQL::LoadApplicationObjectFailedError`](https://graphql-ruby.org/api-doc/GraphQL::LoadApplicationObjectFailedError) が発生しクライアントへ返されます。

この挙動は、mutation クラス内で `def load_application_object_failed` を実装することでカスタマイズできます。例えば:

```ruby
def load_application_object_failed(error)
  raise GraphQL::ExecutionError, "Couldn't find an object for ID: `#{error.id}`"
end
```

または、`load_application_object_failed` が新しいオブジェクトを返す場合、そのオブジェクトが `loads:` の結果として使用されます。

読み込まれたオブジェクトの認可失敗の処理

オブジェクトが読み込まれたがその [`.authorized?` チェック](/authorization/authorization#object-authorization) に失敗した場合、[`GraphQL::UnauthorizedError`](https://graphql-ruby.org/api-doc/GraphQL::UnauthorizedError) が発生します。デフォルトではこれは [`Schema.unauthorized_object`](https://graphql-ruby.org/api-doc/Schema.unauthorized_object) に渡されます（詳しくは [Handling Unauthorized Objects](/authorization/authorization.html#handling-unauthorized-objects) を参照してください）。この挙動は、mutation に `def unauthorized_object(err)` を実装することでカスタマイズできます。例えば:

```ruby
def unauthorized_object(error)
  # Raise a nice user-facing error instead
  raise GraphQL::ExecutionError, "You don't have permission to modify the loaded #{error.type.graphql_name}."
end
```
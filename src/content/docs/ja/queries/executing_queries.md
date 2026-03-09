---
title: クエリの実行
description: schemaでGraphQLクエリを評価する
sidebar:
  order: 0
---
あなたは[`GraphQL::Schema`](https://graphql-ruby.org/api-doc/GraphQL::Schema)を使ってクエリを実行し、結果をRubyのHashとして受け取ることができます。例えば、文字列からクエリを実行するには次のようにします:

```ruby
query_string = "{ ... }"
MySchema.execute(query_string)
# {
#   "data" => { ... }
# }
```

あるいは、複数のクエリを同時に実行することもできます:

```ruby
MySchema.multiplex([
  {query: query_string_1},
  {query: query_string_2},
  {query: query_string_3},
])
# [
#   { "data" => { ... } },
#   { "data" => { ... } },
#   { "data" => { ... } },
# ]
```

また、いくつかのオプションを指定できます:

- `variables:` は `$` で始まる [query variables](https://graphql.org/learn/queries/#variables) に値を提供します
- `context:` はアプリケーション固有のデータを `resolve` 関数に渡すために使います
- `root_value:` はルートレベルの `resolve` 関数に `obj` として渡されます
- `operation_name:` は受信した文字列の中から [named operation](https://graphql.org/learn/queries/#operation-type-and-name) を選択して実行します
- `document:` は既にパースされたクエリ（文字列の代わりに）を受け取ります。詳しくは [`GraphQL.parse`](https://graphql-ruby.org/api-doc/GraphQL.parse) を参照してください
- `validate:` を `false` にすると、このクエリに対する静的バリデーションをスキップできます
- `max_depth:` と `max_complexity:` は schema レベルの値をオーバーライドできます

これらのオプションの一部は以下で詳しく説明します。詳細は [`GraphQL::Query#initialize`](https://graphql-ruby.org/api-doc/GraphQL::Query#initialize) を参照してください。

## 変数

GraphQLはクエリ文字列をパラメータ化する手段として [query variables](https://graphql.org/learn/queries/#variables) を提供します。クエリ文字列に変数が含まれる場合、`{ String => value }` の形式のハッシュで値を渡せます。キーに `"$"` を含めてはいけません。

例えば、クエリに変数を渡すには:

```ruby
query_string = "
  query getPost($postId: ID!) {
    post(id: $postId) {
      title
    }
  }"

variables = { "postId" => "1" }

MySchema.execute(query_string, variables: variables)
```

変数が [`GraphQL::Schema::InputObject`](https://graphql-ruby.org/api-doc/GraphQL::Schema::InputObject) の場合、ネストされたハッシュを渡すことができます。例えば:

```ruby
query_string = "
mutation createPost($postParams: PostInput!, $createdById: ID!){
  createPost(params: $postParams, createdById: $createdById) {
    id
    title
    createdBy { name }
  }
}
"

variables = {
  "postParams" => {
    "title" => "...",
    "body" => "..."
  },
  "createdById" => "5",
}

MySchema.execute(query_string, variables: variables)
```

## コンテキスト

`context:` としてアプリケーション固有の値をGraphQLに渡せます。これは多くの場所で利用可能です:

- `resolve` 関数
- `Schema#resolve_type` フック
- ID の生成や取得

`context:` の一般的な用途は現在のユーザーや認証トークンの保持です。`context:` の値を渡すには、ハッシュを `Schema#execute` に渡します:

```ruby
context = {
  current_user: session[:current_user],
  current_organization: session[:current_organization],
}

MySchema.execute(query_string, context: context)
```

実行時にこれらの値へアクセスできます:

```ruby
field :post, Post do
  argument :id, ID
end

def post(id:)
  context[:current_user] # => #<User id=123 ... >
  # ...
end
```

注意: `context` は渡したハッシュそのものではありません。[`GraphQL::Query::Context`](https://graphql-ruby.org/api-doc/GraphQL::Query::Context) のインスタンスですが、`#[]`、`#[]=`、およびいくつかのメソッドは渡したハッシュに委譲されます。

### スコープされたコンテキスト

`context` はクエリ全体で共有されます。`context` に追加したものはクエリ内の他のどのフィールドからもアクセス可能です（ただし GraphQL-Ruby の実行順序は変わることがあります）。

しかし、「スコープされたコンテキスト」を使うと、現在のフィールドとその子孫フィールドからのみ利用可能な値を `context` に割り当てることができます。例えば、次のようなクエリでは:

```graphql
{
  posts {
    comments {
      author {
        isOriginalPoster
      }
    }
  }
}
```

親の `comments` フィールドに基づいて `isOriginalPoster` を実装するために、スコープされたコンテキストを利用できます。

{% callout warning %}

スコープされたコンテキストを使用すると、[GraphQL specification](https://spec.graphql.org/draft/#sel-EABDLDFAACHAo3V) の違反を引き起こしたり、
オブジェクトが常に同じフィールド値を持つと想定する正規化されたクライアントストアを壊す可能性があります。

この落とし穴とそれを避ける代替手法の詳細については、["Referencing ancestors breaks normalized stores"](https://benjie.dev/graphql/ancestors#breaks-normalized-stores) を参照してください。

{% endcallout %}

`def comments` の中で、`context.scoped_set!` を使って `:current_post` をスコープされたコンテキストに追加します:

```ruby
class Types::Post < Types::BaseObject
  # ...
  def comments
    context.scoped_set!(:current_post, object)
    object.comments
  end
end
```

すると、`User` の中（`author` が `Types::User` を返すと仮定）では `context[:current_post]` をチェックできます:

```ruby
class Types::User < Types::BaseObject
  # ...
  def is_original_poster
    current_post = context[:current_post]
    current_post && current_post.author == object
  end
end
```

「上流」のフィールドが `scoped_set!` で割り当てていれば、`context[:current_post]` は利用可能です。

複数のキーを一度に設定するには `context.scoped_merge!({ ... })` も利用できます。

**注意**: バッチデータローディング（例えば GraphQL-Batch）を使っている場合、GraphQL-Ruby の制御フローがフィールド間でジャンプするため、スコープされたコンテキストが期待通りに動作しないことがあります。その場合は、ローダーを呼ぶ前に `scoped_ctx = context.scoped` でスコープされたコンテキスト参照を取得し、プロミスの中で `scoped_ctx.set!` や `scoped_ctx.merge!` を使ってスコープされたコンテキストを変更してください。例えば:

```ruby
# For use with GraphQL-Batch promises:
scoped_ctx = context.scoped
SomethingLoader.load(:something).then do |thing|
  scoped_ctx.set!(:thing_name, thing.name)
end
```

## ルート値

`root_value:` でルートの `object` 値を渡せます。例えば、クエリを現在の組織に基づかせるには:

```ruby
current_org = session[:current_organization]
MySchema.execute(query_string, root_value: current_org)
```

その値はミューテーションのようなルートレベルのフィールドに渡されます。例えば:

```ruby
class Types::MutationType < GraphQL::Schema::Object
  field :create_post, Post

  def create_post(**args)
    object # => #<Organization id=456 ...>
    # ...
  end
end
```

[`GraphQL::Schema::Mutation`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Mutation) フィールドも、`MutationType` に直接アタッチされている場合は `obj` として `root_value:` を受け取ります。
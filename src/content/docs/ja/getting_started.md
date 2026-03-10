---
title: はじめに
description: ここから始めてください！
---
## インストール

アプリケーションの `Gemfile` に追加して、RubyGems から `graphql` をインストールできます:

```ruby
# Gemfile
gem "graphql"
```

その後、`bundle install` を実行します:

```sh
$ bundle install
```

## はじめに

Rails では、いくつかの [GraphQLジェネレータ](https://rmosolgo.github.io/graphql-ruby/schema/generators#graphqlinstall) を使って始められます:

```sh
# Add graphql-ruby boilerplate and mount graphiql in development
$ rails g graphql:install
# You may need to run bundle install again, as by default graphiql-rails is added on installation.
$ bundle install
# Make your first object type
$ rails g graphql:object Post title:String rating:Int comments:[Comment]
```

または、手動で GraphQL サーバを構築することもできます:

- Types を定義する
- それらを Schema に接続する
- Schema で query を実行する

### Typesの宣言

Types はアプリケーション内のオブジェクトを記述し、[GraphQLのtypeシステム](https://graphql.org/learn/schema/#type-system) の基礎を形成します。

```ruby
# app/graphql/types/post_type.rb
module Types
  class PostType < Types::BaseObject
    description "A blog post"
    field :id, ID, null: false
    field :title, String, null: false
    # fields should be queried in camel-case (this will be `truncatedPreview`)
    field :truncated_preview, String, null: false
    # Fields can return lists of other objects:
    field :comments, [Types::CommentType],
      # And fields can have their own descriptions:
      description: "This post's comments, or null if this post has comments disabled."
  end
end

# app/graphql/types/comment_type.rb
module Types
  class CommentType < Types::BaseObject
    field :id, ID, null: false
    field :post, PostType, null: false
  end
end
```

### Schemaを構築する

Schema を構築する前に、システムのエントリポイントである [システムのエントリポイントである「query root」](https://graphql.org/learn/schema/#the-query-mutation-and-subscription-types) を定義する必要があります:

```ruby
class QueryType < GraphQL::Schema::Object
  description "The query root of this schema"

  field :post, resolver: Resolvers::PostResolver
end
```

この field がどのように解決されるかは、resolver クラスを作成して定義します:

```ruby
# app/graphql/resolvers/post_resolver.rb
module Resolvers
  class PostResolver < BaseResolver
    type Types::PostType, null: false
    argument :id, ID

    def resolve(id:)
      ::Post.find(id)
    end
  end
end
```

その後、`QueryType` を query のエントリポイントとして Schema を構築します:

```ruby
class Schema < GraphQL::Schema
  query Types::QueryType
end
```

この Schema は GraphQL の query を提供する準備ができています！ 他の GraphQL Ruby の機能については [ガイドを参照してください](/guides)。

### Queryを実行する

query 文字列から実行できます:

```ruby
query_string = "
{
  post(id: 1) {
    id
    title
    truncatedPreview
  }
}"
result_hash = Schema.execute(query_string)
# {
#   "data" => {
#     "post" => {
#        "id" => 1,
#        "title" => "GraphQL is nice"
#        "truncatedPreview" => "GraphQL is..."
#     }
#   }
# }
```

Schema 上で query を実行する方法の詳細は [Queryの実行](/queries/executing_queries) を参照してください。

## Relayでの使用

[Relay](https://facebook.github.io/relay/) のバックエンドを構築する場合、次が必要になります:

- Schema の JSON ダンプ。これは [`GraphQL::Introspection::INTROSPECTION_QUERY`](https://github.com/rmosolgo/graphql-ruby/blob/master/lib/graphql/introspection/introspection_query.rb) を送ることで取得できます。
- Relay 固有の GraphQL ヘルパー。詳細は [Connectionガイド](/pagination/connection_concepts)、[Mutationガイド](mutations/mutation_classes)、および [オブジェクト識別ガイド](/schema/object_identification) を参照してください。

## Apollo Clientでの使用

[Apollo Client](https://www.apollographql.com/) は機能が充実し、使いやすい GraphQL クライアントで、主要なビュー層との便利な統合を提供します。`graphql-ruby` サーバに Apollo Client を接続するために特別な対応は必要ありません。

## GraphQL.js Clientでの使用

[GraphQL.js Client](https://github.com/f/graphql.js) はプラットフォームやフレームワークに依存しない小さなクライアントです。GraphQL のリクエストは HTTP 上で送られる単純な query 文字列なので、`graphql-ruby` サーバとよく連携します。
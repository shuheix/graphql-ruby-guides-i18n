---
title: ヘルパー
description: GraphQL フィールドを単独で実行する
sidebar:
  order: 3
---
GraphQL-Ruby には、GraphQL フィールドを単独で実行できるテストヘルパー `run_graphql_field` が付属しています。テストスイートで使うには、スキーマクラスにモジュールをインクルードします:

```ruby
# Mix in `run_graphql_field(...)` to run on `MySchema`
include GraphQL::Testing::Helpers.for(MySchema)
```

その後、[`Testing::Helpers#run_graphql_field`](https://graphql-ruby.org/api-doc/Testing::Helpers#run_graphql_field) を使ってフィールドを実行できます:

```ruby
post = Post.first
graphql_post_title = run_graphql_field("Post.title", post)
assert_equal "100 Great Ideas", graphql_post_title
```

`run_graphql_field` は必須引数を 2 つ受け取ります:

- Field のパス（`Type.field` 形式）
- ランタイムオブジェクト: field を解決するための `nil` でないオブジェクト

さらに、いくつかのキーワード引数を受け取ります:

- `arguments:` — field に渡す GraphQL 引数。Ruby 形式（underscore、symbol）または GraphQL 形式（camel-case、string）で指定できます
- `context:` — このクエリで使用する GraphQL の context

`run_graphql_field` はいくつかの GraphQL 関連の処理を行います:

- 指定された Object Type の `.visible?` をチェックし、表示されない場合はエラーを発生させます
- 与えられたランタイムオブジェクトを GraphQL の Object Type でラップします
- type の `.authorized?` をチェックし、認可に失敗した場合は [`Schema.unauthorized_object`](https://graphql-ruby.org/api-doc/Schema.unauthorized_object) を呼び出します
- field 解決のための arguments を準備します
- field の `#visible?` をチェックし、表示されない場合はエラーを発生させます
- field の `#authorized?` をチェックし、失敗した場合は [`Schema.unauthorized_field`](https://graphql-ruby.org/api-doc/Schema.unauthorized_field) を呼び出します
- 任意の [フィールド拡張](/type_definitions/field_extensions) を呼び出します
- 必要に応じて [Dataloader](/dataloader/overview) および/または GraphQL-Batch を実行します

## 同じオブジェクトでの field の解決

複数の field 解決で同じ type、ランタイムオブジェクト、GraphQL の context を使いたい場合は、[`Testing::Helpers#with_resolution_context`](https://graphql-ruby.org/api-doc/Testing::Helpers#with_resolution_context) を使えます。例えば:

```ruby
# Assuming `include GraphQL::Testing::Helpers.for(MySchema)`
# was used above ...
with_resolution_context(type: "Post", object: example_post, context: { current_user: author }) do |rc|
  assert_equal "100 Great Ideas", rc.run_graphql_field("title")
  assert_equal true, rc.run_graphql_field("viewerIsAuthor")
  assert_equal 5, rc.run_graphql_field("commentsCount")
  # Optionally, pass `arguments:` for the field:
  assert_equal 9, rc.run_graphql_field("commentsCount", arguments: { include_unmoderated: true })
end
```

このメソッドは resolution context（上の例の `rc`）を yield し、そのコンテキストは `run_graphql_field` に応答します。
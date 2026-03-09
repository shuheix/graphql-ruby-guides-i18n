---
title: 統合テスト
description: テストでGraphQLスタック全体を実行する
sidebar:
  order: 2
---
[schema structure](/testing/schema_structure) のテストに加え、GraphQL システムの振る舞いもテストする必要があります。テストには主にいくつかのレベルがあります。

- アプリケーションレベルの振る舞い（ビジネスロジック、権限、永続化など）。これらは API とユーザーインターフェースで共有される可能性があります。
- インターフェースレベルの振る舞い（GraphQL の fields、mutations、エラーシナリオ、HTTP 固有の振る舞いなど）。これらは GraphQL システム固有のものです。
- トランスポートレベルの振る舞い（HTTP ヘッダ、パラメータ、ステータスコードなど）

## アプリケーションレベルの振る舞いのテスト

アプリケーションがどのように振る舞うかについては、アプリケーションのプリミティブを直接検査する単体テストに頼るべきです。たとえば、投稿にはタイトルと本文が必要なら、無効な `Post` が保存に失敗することを検証する `Post` のテストを書くべきです。アプリケーションの他の複数のコンポーネントも同様にテストできます。

- 権限: 例となるリソースやアクターを使って authorization システムをテストします。専用の高レベルフレームワーク（たとえば [Pundit](https://github.com/varvet/pundit)）は、authorization を単体でテストしやすくします。
- ビジネスロジック: システム内でユーザーが行える操作は何ですか？ たとえばブログなら、投稿の下書き作成と公開、コメントのモデレーション、カテゴリによる投稿のフィルタリング、ユーザーのブロックなどが考えられます。これらの操作を単体でテストして、コアコードが正しいことを確認してください。
- 永続化（および外部サービス）: データベースやファイル、サードパーティ API など、アプリが「外部」とどのようにやり取りするかをテストします。これらのやり取りにも専用のテストが必要です。

これら（および他の）アプリケーションレベルの振る舞いを GraphQL なしでテストすることで、テストスイートのオーバーヘッドを減らし、テストシナリオを簡素化できます。

## インターフェースレベルの振る舞いのテスト

アプリケーションを構築した後、人（や他のソフトウェア）がやり取りできるようにインターフェースを提供します。インターフェースはウェブサイトの場合もあれば、GraphQL API の場合もあります。インターフェースにはアプリケーションのプリミティブにマッピングされるトランスポート固有のプリミティブがあります。たとえば React アプリでは、`Post`、`Comment`、`Moderation` といったコンポーネントが対応することがあります（`ThreadComment` や `DraftPost` のようにコンテキスト固有のコンポーネントもあり得ます）。同様に、GraphQL のインターフェースには、基盤となるアプリケーションプリミティブに対応する types や fields（`Post` や `Comment` の type、`Post.isDraft` フィールド、`ModerateComment` mutation など）があります。

GraphQL インターフェースをテストする最良の方法は、統合テストで GraphQL システム全体を実行することです（`MySchema.execute(...)` を使います）。統合テストを使うことで、GraphQL-Ruby の内部システム（バリデーション、解析、authorization、データローディング、レスポンスタイプチェックなど）がすべて動作していることを確認できます。

基本的な統合テストは次のようになります。

```ruby
it "loads posts by ID" do
  query_string = <<-GRAPHQL
    query($id: ID!){
      node(id: $id) {
        ... on Post {
          title
          id
          isDraft
          comments(first: 5) {
            nodes {
              body
            }
          }
        }
      }
    }
  GRAPHQL

  post = create(:post_with_comments, title: "My Cool Thoughts")
  post_id = MySchema.id_from_object(post, Types::Post, {})
  result = MySchema.execute(query_string, variables: { id: post_id })

  post_result = result["data"]["node"]
  # Make sure the query worked
  assert_equal post_id, post_result["id"]
  assert_equal "My Cool Thoughts", post_result["title"]
end
```

システムのさまざまな部分が正しく組み合わさっているか確認するために、特定のシナリオに対する統合テストを追加することもできます。たとえば、あるユーザーにはデータが隠れることを確認するテストを追加できます。

```ruby
it "doesn't show draft posts to anyone except their author" do
  author = create(:user)
  non_author = create(:non_user)
  draft_post = create(:post, draft: true, author: author)

  query_string = <<-GRAPHQL
  query($id: ID!) {
    node(id: $id) {
      ... on Post {
        isDraft
      }
    }
  }
  GRAPHQL

  post_id = MySchema.id_from_object(draft_post, Types::Post, {})

  # Authors can see their drafts:
  author_result = MySchema.execute(query_string, context: { viewer: author }, variables: { id: post_id })
  assert_equal true, author_result["data"]["node"]["isDraft"]

  # Other users can't see others' drafts
  non_author_result = MySchema.execute(query_string, context: { viewer: non_author }, variables: { id: post_id })
  assert_nil author_result["data"]["node"]
end
```

このテストは基盤となる authorization とビジネスロジックを動かし、GraphQL インターフェース層での一種の健全性チェックを提供します。

## トランスポートレベルの振る舞いのテスト

GraphQL は通常 HTTP 上で提供されます。HTTP 入力が GraphQL に対して正しく準備されるかを確認するテストを用意したいでしょう。たとえば次のような点をテストするかもしれません。

- POST データが正しく query 変数に変換されること
- 認証ヘッダが `context[:viewer]` をロードするために使われること

Rails では、たとえば [functional test](https://guides.rubyonrails.org/testing.html#functional-testing-for-controllers) を使うことができます。例:

```ruby
it "loads user token into the viewer" do
  query_string = "{ viewer { username } }"
  post graphql_path, params: { query: query_string }
  json_response = JSON.parse(@response.body)
  assert_nil json_response["data"]["viewer"], "Unauthenticated requests have no viewer"

  # This time, add some authentication to the HTTP request
  user = create(:user)
  post graphql_path,
    params: { query: query_string },
    headers: { "Authorization" => "Bearer #{user.auth_token}" }

  json_response = JSON.parse(@response.body)
  assert_equal user.username, json_response["data"]["viewer"]["username"], "Authenticated requests load the viewer"
end
```
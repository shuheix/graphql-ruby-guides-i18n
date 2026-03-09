---
title: 関連プロジェクト
description: GraphQL Ruby に関するコード、ブログ記事、プレゼンテーション
---
何か追加したいですか？ [GitHub](https://github.com/rmosolgo/graphql-ruby) でプルリクエストを開いてください！

## コード

- `graphql-ruby` + Rails デモ（[ソース](https://github.com/rmosolgo/graphql-ruby-demo) / [heroku](https://graphql-ruby-demo.herokuapp.com)）
- `graphql-ruby` + Sinatra デモ（[ソース](https://github.com/robinjmurphy/ruby-graphql-server-example) / [heroku](https://ruby-graphql-server-example.herokuapp.com/)）
- [`graphql-batch`](https://github.com/shopify/graphql-batch)、query をバッチ処理する実行戦略
- [`graphql-cache`](https://github.com/stackshareio/graphql-cache)、resolver レベルのキャッシュソリューション
- [`graphql-devise`](https://github.com/graphql-devise/graphql_devise)、Devise と連携して認証を扱う gql インターフェース
- [`graphql-docs`](https://github.com/gjtorikian/graphql-docs)、GraphQL 実装から静的な HTML ドキュメントを自動生成するツール
- [`graphql-metrics`](https://github.com/Shopify/graphql-metrics)、サーバーが受け取った GraphQL query の詳細なメトリクスを抽出する plugin
- [`graphql-stitching`](https://github.com/gmac/graphql-stitching-ruby)、複数のローカルおよびリモート schema を単一のグラフに結合して一つとしてクエリできるようにするツール
- [`graphql-groups`](https://github.com/hschne/graphql-groups)、graphql-ruby でグループ化および集計クエリを定義するための DSL
- Rails ヘルパー:
  - [`graphql-activerecord`](https://github.com/goco-inc/graphql-activerecord)
  - [`graphql-rails-resolve`](https://github.com/colepatrickturner/graphql-rails-resolver)
  - [`graphql-query-resolver`](https://github.com/nettofarah/graphql-query-resolver)、N+1 問題を最小化するための graphql-ruby アドオン
  - [`graphql-rails_logger`](https://github.com/jetruby/graphql-rails_logger)、GraphQL query をより読みやすい形式で確認できるログツール
  - [`apollo_upload_server-ruby`](https://github.com/jetruby/apollo_upload_server-ruby)、フロントエンドでの [`apollo-upload-client`](https://github.com/jaydenseric/apollo-upload-client) ライブラリを用いた multipart/form-data を介したファイルアップロードを可能にする middleware
  - [`graphql-sources`](https://github.com/ksylvest/graphql-sources)、`ActiveRecord`、`ActiveStorage`、`Rails.cache` などの利用を簡素化する一般的な GraphQL [sources](https://graphql-ruby.org/dataloader/sources.html) のコレクション
  - [`graphql-filters`](https://github.com/moku-io/graphql-filters)、リストフィールドのための完全に型付けされたフィルターを定義する DSL
- [`search_object_graphql`](https://github.com/rstankov/SearchObjectGraphQL)、GraphQL 用の検索 resolver を定義するための DSL
- [`action_policy-graphql`](https://github.com/palkan/action_policy-graphql)、[`action_policy`](https://github.com/palkan/action_policy) を GraphQL アプリケーションの認可フレームワークとして利用するための統合
- [`graphql_rails`](https://github.com/samesystem/graphql_rails)、Rails 流の GraphQL ビルドツール
- [`graphql-rails-generators`](https://github.com/ajsharp/graphql-rails-generators)、ActiveRecord モデルから graphql-ruby の mutations、types、input types を生成するツール
- [`graphql-ruby-fragment_cache`](https://github.com/DmitryTsepelev/graphql-ruby-fragment_cache)、レスポンスのフラグメントをキャッシュするツール
- [`graphql-ruby-persisted_queries`](https://github.com/DmitryTsepelev/graphql-ruby-persisted_queries)、[Apollo persisted queries](https://github.com/apollographql/apollo-link-persisted-queries) の実装
- [`rubocop-graphql`](https://github.com/DmitryTsepelev/rubocop-graphql)、ベストプラクティスを強制するための [rubocop](https://github.com/rubocop-hq/rubocop) 拡張
- [`apollo-federation-ruby`](https://github.com/Gusto/apollo-federation-ruby)、Apollo Federation の [subgraph spec](https://www.apollographql.com/docs/federation/subgraph-spec/) の Ruby 実装

## ブログ記事

- Rails 上で GraphQL と Relay を使ってブログを作る — [導入](https://medium.com/@gauravtiwari/graphql-and-relay-on-rails-getting-started-955a49d251de)、[パート1](https://medium.com/@gauravtiwari/graphql-and-relay-on-rails-creating-types-and-schema-b3f9b232ccfc)、[パート2](https://medium.com/@gauravtiwari/graphql-and-relay-on-rails-first-relay-powered-react-component-cb3f9ee95eca)
- https://medium.com/@khor/relay-facebook-on-rails-8b4af2057152
- https://blog.jacobwgillespie.com/from-rest-to-graphql-b4e95e94c26b#.4cjtklrwt
- https://jonsimpson.ca/parallel-graphql-resolvers-with-futures/
- Active Storage と GraphQL の連携： [直接アップロード](https://evilmartians.com/chronicles/active-storage-meets-graphql-direct-uploads) と [添付ファイルの URL を公開する方法](https://evilmartians.com/chronicles/active-storage-meets-graphql-pt-2-exposing-attachment-urls)
- [Action Policy を使って GraphQL API で権限を公開する方法](https://evilmartians.com/chronicles/exposing-permissions-in-graphql-apis-with-action-policy)
- [graphql-ruby で非 null 違反を正しく報告する方法](https://evilmartians.com/chronicles/reporting-non-nullable-violations-in-graphql-ruby-properly)
- [Ruby、Rails、Active Record と N+1 を回避した GraphQL のやり方](https://evilmartians.com/chronicles/how-to-graphql-with-ruby-rails-active-record-and-no-n-plus-one)

## スクリーンキャスト

- [Rails 5 における GraphQL の基本](https://rubyplus.com/episodes/271-GraphQL-Basics-in-Rails-5)

## プレゼンテーション

- [GraphQL でレガシーコードベースを救う](https://speakerdeck.com/nettofarah/rescuing-legacy-codebases-with-graphql-1) by [@nettofarah](https://twitter.com/nettofarah)

## チュートリアル

- [How To GraphQL](https://www.howtographql.com/graphql-ruby/0-introduction/) by [@rstankov](https://github.com/rstankov)

- [GraphQL Ruby CRUD チュートリアル](https://www.blook.pub/books/graphql-rails-tutorial) by [@kohheepeace](https://twitter.com/kohheepeace)

- Rails/GraphQL + React/Apollo チュートリアル（[パート1](https://evilmartians.com/chronicles/graphql-on-rails-1-from-zero-to-the-first-query)、[パート2](https://evilmartians.com/chronicles/graphql-on-rails-2-updating-the-data)、[パート3](https://evilmartians.com/chronicles/graphql-on-rails-3-on-the-way-to-perfection)） by [@evilmartians](https://twitter.com/evilmartians)
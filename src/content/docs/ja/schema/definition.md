---
title: 定義
description: スキーマの定義
sidebar:
  order: 1
---
GraphQL システムは _schema_ と呼ばれます。schema はシステム内のすべての types と fields を含みます。schema はクエリを実行し、[introspection system](/schema/introspection) を公開します。

あなたの GraphQL schema は [`GraphQL::Schema`](https://graphql-ruby.org/api-doc/GraphQL::Schema) を継承するクラスです。例えば:

```ruby
class MyAppSchema < GraphQL::Schema
  max_complexity 400
  query Types::Query
  use GraphQL::Dataloader

  # Define hooks as class methods:
  def self.resolve_type(type, obj, ctx)
    # ...
  end

  def self.object_from_id(node_id, ctx)
    # ...
  end

  def self.id_from_object(object, type, ctx)
    # ...
  end
end
```

schema の設定メソッドは多数あります。

GraphQL の types を定義する方法については、それぞれの type のガイドを参照してください: [object types](/type_definitions/objects), [interface types](/type_definitions/interfaces), [union types](/type_definitions/unions), [input object types](/type_definitions/input_objects), [enum types](/type_definitions/enums), および [scalar types](/type_definitions/scalars)。

## スキーマ内の types

- [`Schema.query`](https://graphql-ruby.org/api-doc/Schema.query), [`Schema.mutation`](https://graphql-ruby.org/api-doc/Schema.mutation), および [`Schema.subscription`](https://graphql-ruby.org/api-doc/Schema.subscription) は schema の [entry-point types](https://graphql.org/learn/schema/#the-query-mutation-and-subscription-types) を宣言します。
- [`Schema.orphan_types`](https://graphql-ruby.org/api-doc/Schema.orphan_types) は、[Interfaces](/type_definitions/interfaces) を実装しているが schema 内で field の戻り値としては使われていない object types を宣言します。この特定のケースについては、[Orphan Types](/type_definitions/interfaces#orphan-types) を参照してください。

### Lazy-loading types

開発環境では、GraphQL-Ruby は type 定義の読み込みを必要になるまで遅延させることができます。これを利用するには、いくつか設定が必要です:

- schema に `use GraphQL::Schema::Visibility` を追加します。([`GraphQL::Schema::Visibility`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Visibility) は lazy loading をサポートしており、将来の GraphQL-Ruby のバージョンでデフォルトになります。既存の visibility 実装がある場合は [Migration Notes](/authorization/visibility#migration-notes) を参照してください。)
- エントリーポイントの type 定義をブロック内に移動します。例えば:

  ```diff
  - query Types::Query
  + query { Types::Query }
  ```

- 必要に応じて、field の type もブロックに移動します:

  ```diff
  - field :posts, [Types::Post] # Loads `types/post.rb` immediately
  + field :posts do
  +   type([Types::Post]) # Loads `types/post.rb` when this field is used in a query
  + end
  ```

これらのパターンを強制するには、GraphQL-Ruby に同梱されている Rubocop ルールを有効にできます:

- `GraphQL/RootTypesInBlock` は `query`、`mutation`、`subscription` がすべてブロック内で定義されていることを保証します。
- `GraphQL/FieldTypeInBlock` は、組み込みでない field の戻り値の types がブロック内で定義されていることを保証します。

## オブジェクトの識別

いくつかの GraphQL 機能は、オブジェクトを読み込むために一意な ID を使用します:

- the `node(id:)` field looks up objects by ID (See [Object Identification](/schema/object_identification) for more about Relay-style object identification.)
- `loads:` 設定を持つ任意の argument は ID によってオブジェクトを検索します
- the [ObjectCache](/object_cache/overview) uses IDs in its caching scheme

これらの機能を使うには、UUID を生成し、それでオブジェクトを取得するメソッドを提供する必要があります:

[`Schema.object_from_id`](https://graphql-ruby.org/api-doc/Schema.object_from_id) は GraphQL-Ruby によってデータベースからオブジェクトを直接読み込むために呼ばれます。通常は `node(id: ID!): Node` フィールド (参照: [`GraphQL::Types::Relay::Node`](https://graphql-ruby.org/api-doc/GraphQL::Types::Relay::Node))、Argument の [loads:](/mutations/mutation_classes#auto-loading-arguments)、または [ObjectCache](/object_cache/overview) によって使用されます。このメソッドは一意な ID を受け取り、その ID に対応するオブジェクトを返す必要があります。オブジェクトが見つからない場合、または現在のユーザーから隠すべき場合は `nil` を返します。

[`Schema.id_from_object`](https://graphql-ruby.org/api-doc/Schema.id_from_object) は `Node.id` を実装するために使われます。与えられたオブジェクトに対して一意な ID を返すべきで、この ID は後で `object_from_id` に渡されてオブジェクトを再取得します。

さらに、[`Schema.resolve_type`](https://graphql-ruby.org/api-doc/Schema.resolve_type) は、interface や [union](/type_definitions/unions) types を返す field のランタイムでの Object type を取得するために GraphQL-Ruby によって呼ばれます。([interface](/type_definitions/interfaces))

## エラー処理

- [`Schema.type_error`](https://graphql-ruby.org/api-doc/Schema.type_error) はランタイムでの型エラーを処理します。詳細は [Type errors guide](/errors/type_errors) を参照してください。
- [`Schema.rescue_from`](https://graphql-ruby.org/api-doc/Schema.rescue_from) はアプリケーションエラーのためのエラーハンドラを定義します。詳細は [error handling guide](/errors/error_handling) を参照してください。
- [`Schema.parse_error`](https://graphql-ruby.org/api-doc/Schema.parse_error) と [`Schema.query_stack_error`](https://graphql-ruby.org/api-doc/Schema.query_stack_error) はバグトラッカーにエラーを報告するためのフックを提供します。

## デフォルトの制限

- [`Schema.max_depth`](https://graphql-ruby.org/api-doc/Schema.max_depth) と [`Schema.max_complexity`](https://graphql-ruby.org/api-doc/Schema.max_complexity) は受信クエリに対していくつかの制限を適用します。詳細は [Complexity and Depth](/queries/complexity_and_depth) を参照してください。
- [`Schema.default_max_page_size`](https://graphql-ruby.org/api-doc/Schema.default_max_page_size) は [connection fields](/pagination/overview) に制限を適用します。
- [`Schema.validate_timeout`](https://graphql-ruby.org/api-doc/Schema.validate_timeout)、[`Schema.validate_max_errors`](https://graphql-ruby.org/api-doc/Schema.validate_max_errors)、および [`Schema.max_query_string_tokens`](https://graphql-ruby.org/api-doc/Schema.max_query_string_tokens) はすべてクエリ実行に制限を適用します。詳細は [Timeout](/queries/timeout) を参照してください。

## Introspection

- [`Schema.extra_types`](https://graphql-ruby.org/api-doc/Schema.extra_types) は、SDL に出力され、introspection クエリで返されるべきだが schema 内で他に使われていない types を宣言します。
- [`Schema.introspection`](https://graphql-ruby.org/api-doc/Schema.introspection) は schema に [custom introspection system](/schema/introspection) を結びつけることができます。

## 認可

- [`Schema.unauthorized_object`](https://graphql-ruby.org/api-doc/Schema.unauthorized_object) と [`Schema.unauthorized_field`](https://graphql-ruby.org/api-doc/Schema.unauthorized_field) は、クエリ実行中に [authorization hooks](/authorization/authorization) が `false` を返したときに呼ばれます。

## 実行設定

- [`Schema.trace_with`](https://graphql-ruby.org/api-doc/Schema.trace_with) は tracer モジュールを接続します。詳細は [Tracing](/queries/tracing) を参照してください。
- [`Schema.query_analyzer`](https://graphql-ruby.org/api-doc/Schema.query_analyzer) と {{ "Schema.multiplex_analyzer" }} は事前のクエリ解析用のプロセッサを受け取ります。詳細は [Analysis](/queries/ast_analysis) を参照してください。
- [`Schema.default_logger`](https://graphql-ruby.org/api-doc/Schema.default_logger) はランタイム用のロガーを設定します。詳細は [Logging](/queries/logging) を参照してください。
- [`Schema.context_class`](https://graphql-ruby.org/api-doc/Schema.context_class) と [`Schema.query_class`](https://graphql-ruby.org/api-doc/Schema.query_class) は実行時に使用するカスタムサブクラスを schema に紐付けます。
- [`Schema.lazy_resolve`](https://graphql-ruby.org/api-doc/Schema.lazy_resolve) は [lazy execution](/schema/lazy_execution) に対応するクラスを登録します。

## プラグイン

- [`Schema.use`](https://graphql-ruby.org/api-doc/Schema.use) は schema に plugin を追加します。例えば、[`GraphQL::Dataloader`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader) や [`GraphQL::Schema::Visibility`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Visibility) はこの方法でインストールされます。

## 本番環境での考慮事項

- __Parser caching__: アプリケーションが GraphQL の _files_（クエリやスキーマ定義）をパースする場合、[`GraphQL::Language::Cache`](https://graphql-ruby.org/api-doc/GraphQL::Language::Cache) を有効にすることで利点があるかもしれません。
- __Eager loading the library__: デフォルトでは、GraphQL-Ruby は必要に応じて定数を autoload します。本番環境では、代わりに eager load するべきで、`GraphQL.eager_load!` を使用します。

  - Rails: 自動的に有効になります。(ActiveSupport が `.eager_load!` を呼び出します。)
  - Sinatra: アプリケーションファイルに `configure(:production) { GraphQL.eager_load! }` を追加してください。
  - Hanami: アプリケーションファイルに `environment(:production) { GraphQL.eager_load! }` を追加してください。
  - その他のフレームワーク: 本番モードでアプリケーションが起動するときに `GraphQL.eager_load!` を呼び出してください。

  詳細は [`GraphQL::Autoload#eager_load!`](https://graphql-ruby.org/api-doc/GraphQL::Autoload#eager_load!) を参照してください。
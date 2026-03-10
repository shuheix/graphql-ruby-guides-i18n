---
title: ジェネレータ
description: Rails のジェネレータを使って GraphQL をインストールし、新しい types をスキャフォールドします。
sidebar:
  order: 3
---
If you're using GraphQL with Ruby on Rails, you can use generators to:

- [GraphQL をセットアップ](#graphqlinstall)（[GraphiQL](https://github.com/graphql/graphiql)、[GraphQL::Batch](https://github.com/Shopify/graphql-batch)、および [Relay](https://facebook.github.io/relay/) を含む）
- [types をスキャフォールド](#scaffolding-types)
- [Relay mutation をスキャフォールド](#scaffolding-mutations)
- [ActiveRecord create/update/delete mutation をスキャフォールド](#scaffolding-activerecord-mutations)
- [GraphQL::Batch loader をスキャフォールド](#scaffolding-loaders)

## graphql:install の実行

Rails アプリに GraphQL を追加するには、`graphql:install` を実行します:

```
rails generate graphql:install
```

これにより、次の処理が行われます:

- `app/graphql/` にフォルダ構成を作成します
- schema 定義を追加します
- 基底の type クラスを追加します
- `Query` type の定義を追加します
- 基底の mutation クラス付きで `Mutation` type の定義を追加します
- query を実行するためのルートとコントローラを追加します
- [`graphiql-rails`](https://github.com/rmosolgo/graphiql-rails) をインストールします
- [`ActiveRecord::QueryLogs`](https://api.rubyonrails.org/classes/ActiveRecord/QueryLogs.html) を有効にし、GraphQL 関連のメタデータ（[`GraphQL::Current`](https://graphql-ruby.org/api-doc/GraphQL::Current) を用いる）を追加します

インストール後に新しい schema を確認するには、次を行います:

- `bundle install`
- `rails server`
- ブラウザで `localhost:3000/graphiql` を開きます

### オプション

- `--directory=DIRECTORY` は生成ファイルを保存するディレクトリを指定します（デフォルトは `app/graphql`）
- `--schema=MySchemaName` は schema の名前付けに使われます（デフォルトは `#{app_name}Schema`）
- `--skip-graphiql` は `graphiql-rails` をセットアップから除外します
- `--skip-mutation-root-type` は mutation root type を作成しません
- `--skip-query-logs` は QueryLogs のセットアップをスキップします
- `--relay` はスキーマに [Relay](https://facebook.github.io/relay/)-固有のコードを追加します
- `--batch` は [GraphQL::Batch](https://github.com/Shopify/graphql-batch) を Gemfile に追加し、スキーマにそのセットアップを含めます
- `--playground` は `graphql_playground-rails` をセットアップに含めます（`/playground` にマウントされます）
- `--api` は API 専用アプリ向けの小さなスタックを作成します

## Types のスキャフォールド

いくつかのジェネレータにより、GraphQL の types をプロジェクトに追加できます。オプションを確認するには `-h` を付けて実行してください:

- `rails g graphql:object`
- `rails g graphql:input`
- `rails g graphql:interface`
- `rails g graphql:union`
- `rails g graphql:enum`
- `rails g graphql:scalar`

### ActiveRecord カラムの自動抽出

`graphql:object` と `graphql:input` ジェネレータは、同名の ActiveRecord クラスが存在するかを検出し、データベースのカラムを適切な GraphQL 型と nullability 判定を用いて field/argument としてスキャフォールドできます。

### オプション

- `--namespaced-types` は `object`/`input`/`interface`/... 各 type を別々の `Types::Objects::*`/`Types::Inputs::*`/`Types::Interfaces::*`/... 名前空間およびフォルダ下に生成します

## Mutation のスキャフォールド

Relay Classic の mutation を準備するには、次を実行します:

```
rails g graphql:mutation #{mutation_name}
```

## ActiveRecord Mutation のスキャフォールド

与えられたモデルに対する Relay Classic の create/update/delete mutation を生成するには、次を実行します:

```
rails g graphql:mutation_create #{model_class_name}
rails g graphql:mutation_update #{model_class_name}
rails g graphql:mutation_delete #{model_class_name}
```

`model_class_name` は `namespace/class_type` と `Namespace::ClassType` の両方の形式を受け付けます。この mutation も `--namespaced-types` フラグを受け取り、type ジェネレータでスキャフォールドされる Object および Input クラスと整合させることができます。

## Loader のスキャフォールド

GraphQL::Batch loader を準備するには、次を実行します:

```
rails g graphql:loader
```
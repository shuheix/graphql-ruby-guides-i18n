---
title: スキーマ構造
description: スキーマの変更が後方互換であることを確認する
sidebar:
  order: 1
---
GraphQLスキーマの構造変更は2つのカテゴリに分かれます:

- __破壊的な変更__ は、以前は有効だったクエリを無効にする可能性があります。例えば、`title` フィールドを削除すると、そのフィールドをクエリしようとする人は応答データの代わりにバリデーションエラーを受け取ります。
- __非破壊的な変更__ は、以前有効だったクエリを壊すことなくスキーマにオプションを追加します。

_破壊的な_ 変更は API クライアントにとって問題になることがあり、アプリケーションが壊れる可能性があります。しかし、場合によっては必要になることもあります。_非破壊的な_ 変更はスキーマに新しい部分を追加するだけなので、既存のクエリには影響しません。

スキーマ構造の変更を管理するためのいくつかのヒントを示します。

## `.graphql` スキーマダンプを維持する

構造変更を通常のコードレビューの一部にするために、`schema.graphql` アーティファクトをプロジェクトに追加してください。こうすることで、スキーマ構造への変更はプルリクエストにそのファイルの差分として明確に表示されます。

この手法については [GraphQL-Rubyによるスキーマ変更の追跡](https://rmosolgo.github.io/ruby/graphql/2017/03/16/tracking-schema-changes-with-graphql-ruby) を参照するか、スキーマダンプを生成する組み込みの [`GraphQL::RakeTask`](https://graphql-ruby.org/api-doc/GraphQL::RakeTask) を参照してください。

## 破壊的変更を自動的にチェックする

開発中や CI の際に破壊的変更をチェックするために [GraphQL::SchemaComparator](https://github.com/xuorig/graphql-schema_comparator) を使用できます。サーバーに対して通常実行されるクエリのダンプを保持している場合は、それらのクエリを直接検証するために `GraphQL::StaticValidation` を利用することもできます。下のような Rake タスクを使って、既存のクエリと互換性のない変更を検出できます。

```ruby
namespace :graphql do
  namespace :queries do
    desc 'Validates GraphQL queries against the current schema'
    task validate: [:environment] do
      queries_file = 'test/fixtures/files/queries.json'
      queries = Oj.load(File.read(queries_file))

      Validate.run_validate(queries, MySchema)
    end

    module Validate
      def self.run_validate(queries, schema)
        puts '⏳  Validating queries...'
        puts "\n"

        results = queries.map { |query| schema.validate(query) }
        errors = results.flatten

        if errors.empty?
          puts '✅  All queries are valid'
        else
          print_errors(errors)
        end
      end

      def self.print_errors(errors)
        puts 'Detected the following errors:'
        puts "\n"

        errors.each do |error|
          path = error.path.join(', ')
          puts "❌  #{path}: #{error.message}"
        end
      end
    end
  end
end
```
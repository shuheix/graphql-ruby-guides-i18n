---
title: インストール
description: GraphQL::Pro の始め方
sidebar:
  order: 1
pro: true
---
`GraphQL::Pro` は Ruby の gem として配布されています。`GraphQL::Pro` を購入すると認証情報が届きます。これを bundler に登録してください:

```sh
bundle config gems.graphql.pro #{YOUR_CREDENTIALS}
```

その後、カスタムの `source` を使って Gemfile に `graphql-pro` を追加できます:

```ruby
source "https://gems.graphql.pro" do
  gem "graphql-pro"
end
```

次に、Bundler で gem をインストールします:

```sh
bundle install
```

それでは、`GraphQL::Pro` の機能をいくつか試してみてください！

## 更新

`GraphQL::Pro` を更新するには、Bundler を使います:

```sh
bundle update graphql-pro
```

バージョン間の差分は必ず [変更履歴](https://github.com/rmosolgo/graphql-ruby/blob/master/CHANGELOG-pro.md) を確認してください。

## 依存関係

`graphql-pro 1.0.0` は `graphql ~>1.4` を必要とします。最新バージョンは `graphql =>1.7.6` を必要とします。

## 整合性の検証

`graphql-pro` の整合性は、そのチェックサムを取得して [公開されているチェックサム](https://github.com/rmosolgo/graphql-ruby/blob/master/guides/pro/checksums) と比較することで検証できます。

`Rakefile` に `graphql:pro:validate` タスクを含めてください:

```ruby
# Rakefile
require "graphql/rake_task/validate"
```

その後、バージョンを指定して実行します:

```
$ bundle exec rake graphql:pro:validate[1.0.0]
Validating graphql-pro v1.0.0
  - Checking for graphql-pro credentials...
    ✓ found
  - Fetching the gem...
    ✓ fetched
  - Validating digest...
    ✓ validated from GitHub
    ✓ validated from graphql-ruby.org
✔ graphql-pro 1.0.0 validated successfully!
```

失敗した場合は、{% open_an_issue "GraphQL Pro installation failure" %}してください:

```
Validating graphql-pro v1.4.800
  - Checking for graphql-pro credentials...
    ✓ found
  - Fetching the gem...
    ✓ fetched
  - Validating digest...
    ✘ SHA mismatch:
      Downloaded:       c9cab2619aa6540605ce7922784fc84dbba3623383fdce6b17fde01d8da0aff49d666810c97f66310013c030e3ab7712094ee2d8f1ea9ce79aaf65c1684d992a
      GitHub:           404: Not Found
      graphql-ruby.org: 404: Not Found

      This download of graphql-pro is invalid, please open an issue:
      https://github.com/rmosolgo/graphql-ruby/issues/new?title=graphql-pro%20digest%20mismatch%20(1.4.800)
```
---
title: Cベースのパーサ
description: GraphQL::CParser gem は組み込みのパーサのドロップイン置き換えです
sidebar:
  order: 1
---
GraphQL-Ruby には純粋な Ruby 製のパーサが含まれていますが、C 拡張としてより高速なパーサが利用できます。利用するには、プロジェクトに [`graphql-c_parser` gem](https://rubygems.org/gems/graphql-c_parser) を追加してください。例:

```ruby
bundle add graphql-c_parser
```

アプリが `graphql-c_parser` を `require` すると、Cベースのパーサがデフォルトのパーサ（[`GraphQL.default_parser`](https://graphql-ruby.org/api-doc/GraphQL.default_parser) として）としてインストールされます。Bundler は自動的にこのライブラリを require しますが、手動で require することもできます:

```ruby
require "graphql/c_parser"
```

この代替パーサは高速で、メモリ使用量も少なくなります。

このライブラリはまた、Cベースのパーサを直接呼び出すための `GraphQL.scan_with_c` と `GraphQL.parse_with_c` を追加します。
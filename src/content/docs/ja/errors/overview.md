---
title: GraphQLにおけるエラー
description: GraphQLのエラーに関する概念的な入門
sidebar:
  order: 0
redirect_from:
- "/schema/type_errors/"
- "/queries/error_handling/"
---
GraphQLには非常に多くの種類のエラーがあります。本ガイドでは主要なカテゴリをいくつか紹介し、それらがどのような場合に適用されるかを説明します。

## バリデーションエラー

GraphQLは強い型付けなので、実行前にすべてのqueriesを検証します。受け取ったqueryが無効な場合、そのqueryは実行されず、代わりに `"errors"` を含むレスポンスが返されます:

```ruby
{
  "errors" => [ ... ]
}
```

各エラーは message、line、column、および path を持ちます。

検証ルールはGraphQLの仕様の一部であり、GraphQL-Rubyに組み込まれているため、この挙動をカスタマイズする方法はあまりありません。唯一の例外は、クエリ実行時に `validate: false` を渡して検証を完全にスキップすることです。

特定の件数のエラー後に検証を停止するようにschemaを設定するには、[`Schema.validate_max_errors`](https://graphql-ruby.org/api-doc/Schema.validate_max_errors) を設定してください。また、このステップにタイムアウトを追加するには [`Schema.validate_timeout`](https://graphql-ruby.org/api-doc/Schema.validate_timeout) を使えます。

## 解析エラー

GraphQL-Rubyは実行前の解析（pre-execution analysis）をサポートしており、ここでクエリを実行する代わりに `"errors"` を返すことがあります。詳細は [解析ガイド](queries/ast_analysis) を参照してください。

## GraphQLの不変条件

GraphQL-Rubyがqueryを実行している間に満たされるべき制約がいくつかあります。例えば:

- Non-null な field は `nil` を返してはいけません。
- Interface と union の type は、オブジェクトが当該 interface/union に属する type として解決される必要があります。

これらの制約はGraphQLの仕様の一部であり、違反が発生した場合は何らかの対応が必要です。詳細は [Type エラー](/errors/type_errors) を参照してください。

## トップレベルの "errors"

GraphQLの仕様では、query実行中のエラー情報を含むトップレベルの `"errors"` キーが定められています。部分的に成功した場合は、`"errors"` と `"data"` の両方が存在することがあります。

自分のschema内では、コード中で `GraphQL::ExecutionError`（またはそのサブクラス）をraiseすることで、`"errors"` キーに項目を追加できます。詳しくは [Execution Errors ガイド](/errors/execution_errors) を参照してください。

## 処理されたエラー

schema は `rescue_from` を使って、field 実行中に発生する特定のエラーをハンドラーで処理するよう設定できます。詳細は [エラー処理ガイド](/errors/error_handling) を参照してください。

## 未処理のエラー（クラッシュ）

`raise` されたエラーが `rescue` されない場合、GraphQLのqueryは完全にクラッシュし、周囲のコード（例えば Rails のコントローラ）が例外を処理する必要があります。

例えば、Rails では一般的にジェネリックな `500` ページを返すでしょう。

## データとしてのエラー

エンドユーザ（人間）にエラーメッセージを読ませたい場合、エラーを_schema_の中で通常のGraphQLのfieldsやtypesとして表現できます。このアプローチでは、エラーは強く型付けされたデータとなり、他のアプリケーションデータと同様にschema内でquery可能です。

このアプローチの詳細は [Mutation エラー](/mutations/mutation_errors.html#errors-as-data) を参照してください。
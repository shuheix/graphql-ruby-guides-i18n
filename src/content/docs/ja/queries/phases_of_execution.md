---
title: 実行フェーズ
description: GraphQLがクエリを実行する際の手順
sidebar:
  order: 2
---
GraphQLがクエリ文字列を受け取ると、次の手順を経ます:

- トークン化: [`GraphQL::Language::Lexer`](https://graphql-ruby.org/api-doc/GraphQL::Language::Lexer) が文字列をトークンのストリームに分割します
- パース: [`GraphQL::Language::Parser`](https://graphql-ruby.org/api-doc/GraphQL::Language::Parser) がトークンのストリームから抽象構文木 (AST) を構築します
- 検証: [`GraphQL::StaticValidation::Validator`](https://graphql-ruby.org/api-doc/GraphQL::StaticValidation::Validator) が受け取ったASTがschemaに対する有効なqueryであるかを検証します
- 解析: query analyzers が存在する場合、[`GraphQL::Analysis.analyze_query`](https://graphql-ruby.org/api-doc/GraphQL::Analysis.analyze_query) で実行されます
- 実行: query を走査し、`resolve` 関数が呼び出されてレスポンスが構築されます
- 応答: レスポンスは [`GraphQL::Query::Result`](https://graphql-ruby.org/api-doc/GraphQL::Query::Result) として返されます
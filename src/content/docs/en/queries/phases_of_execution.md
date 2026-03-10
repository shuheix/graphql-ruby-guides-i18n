---
title: Phases of Execution
description: The steps GraphQL takes to run your query
sidebar:
  order: 2
---

When GraphQL receives a query string, it goes through these steps:

- Tokenize: [`GraphQL::Language::Lexer`](https://graphql-ruby.org/api-doc/GraphQL::Language::Lexer) splits the string into a stream of tokens
- Parse: [`GraphQL::Language::Parser`](https://graphql-ruby.org/api-doc/GraphQL::Language::Parser) builds an abstract syntax tree (AST) out of the stream of tokens
- Validate: [`GraphQL::StaticValidation::Validator`](https://graphql-ruby.org/api-doc/GraphQL::StaticValidation::Validator) validates the incoming AST as a valid query for the schema
- Analyze: If there are any query analyzers, they are run with [`GraphQL::Analysis.analyze_query`](https://graphql-ruby.org/api-doc/GraphQL::Analysis.analyze_query)
- Execute: The query is traversed, `resolve` functions are called and the response is built
- Respond: The response is returned as a [`GraphQL::Query::Result`](https://graphql-ruby.org/api-doc/GraphQL::Query::Result)

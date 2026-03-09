---
title: Mutation ルート
description: Mutationオブジェクトはmutation操作のエントリポイントです。
sidebar:
  order: 0
---
GraphQLのmutationはすべて`mutation`キーワードで始まります:

```graphql
mutation($accountNumber: ID!, $newBalance: Int!) {
# ^^^^ here
  setAccountBalance(accountNumber: $accountNumber, newBalance: $newBalance) {
    # ...
  }
}
```

`mutation`で始まる操作はGraphQLランタイムによって特別に扱われます: root fieldsは順次実行されることが保証されます。こうすることで、一連のmutationの影響が予測可能になります。

mutationは特定のGraphQLオブジェクトである`Mutation`によって実行されます。このオブジェクトは他のGraphQLオブジェクトと同様に定義します:

```ruby
class Types::Mutation < Types::BaseObject
  # ...
end
```

その後、`mutation(...)`設定でschemaに設定する必要があります:

```ruby
class Schema < GraphQL::Schema
  # ...
  mutation(Types::Mutation)
end
```

これで、リクエストが`mutation`キーワードを使用するたびに、処理は`Mutation`に渡されます。

mutation fieldを定義するためのいくつかのヘルパーについては[Mutationクラス](/mutations/mutation_classes)を参照してください。
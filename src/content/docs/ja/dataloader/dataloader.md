---
title: Dataloader
description: Dataloader は Fibers と Sources をオーケストレーションします
sidebar:
  order: 2
---
[`GraphQL::Dataloader`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader) のインスタンスはクエリごと（または multiplex）に作成され、次のことを行います:

- GraphQL 実行の間、[Source](/dataloader/sources) のインスタンスをキャッシュする
- 保留中の Fibers を実行してデータ要件を解決し、GraphQL 実行を継続する

クエリ中に、dataloader インスタンスへは次の方法でアクセスできます:

- [`GraphQL::Query::Context#dataloader`](https://graphql-ruby.org/api-doc/GraphQL::Query::Context#dataloader)（クエリコンテキストが利用できる場所ならどこでも、`context.dataloader`）
- [`GraphQL::Schema::Object#dataloader`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Object#dataloader)（リゾルバメソッド内での `dataloader`）
- [`GraphQL::Schema::Resolver#dataloader`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Resolver#dataloader)（Resolver、Mutation、Subscription クラスの `def resolve` 内での `dataloader`）

## Fiber ライフサイクルフック

内部では、`Dataloader` は必要に応じて Fibers を作成し、それらを使って GraphQL を実行し、`Source` クラスからデータをロードします。これらの Fiber には複数のライフサイクルフックで介入できます。これらのフックを実装するには、カスタムのサブクラスを作成して以下のメソッドに対する実装を提供してください:

```ruby
class MyDataloader < GraphQL::Dataloader # or GraphQL::Dataloader::AsyncDataloader
  # ...
end
```

その後、組み込みのものの代わりにカスタマイズした dataloader を使います:

```diff
  class MySchema < GraphQL::Schema
-   use GraphQL::Dataloader
+   use MyDataloader
  end
```

- __[`GraphQL::Dataloader#get_fiber_variables`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader#get_fiber_variables)__ は Fiber を作成する前に呼ばれます。デフォルトでは親 Fiber の変数（`Thread.current[...]` から）を含むハッシュを返します。独自実装ではこのハッシュに項目を追加できます。
- __[`GraphQL::Dataloader#set_fiber_variables`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader#set_fiber_variables)__ は新しい Fiber の内部で呼ばれます。`get_fiber_variables` から返されたハッシュが渡されます。このメソッドを使って新しい Fiber の内部で「グローバル」な状態を初期化できます。
- __[`GraphQL::Dataloader#cleanup_fiber`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader#cleanup_fiber)__ は Dataloader Fiber が終了する直前に呼ばれます。`set_fiber_variables` で準備した状態をここでクリーンアップできます。
---
title: カスタム接続
description: GraphQL-Rubyでのカーソルベースの接続の構築と利用
sidebar:
  order: 3
---
GraphQL-Ruby は ActiveRecord、Sequel、Mongoid、そして Ruby Arrays に対する組み込みの connection サポートを提供しています。詳細は [Connections の使用](/pagination/using_connections) ガイドを参照してください。

独自のデータオブジェクトに基づく connection を提供したい場合は、カスタム connection を作成できます。実装は次のいくつかの要素から成ります。

- アプリケーションオブジェクト -- GraphQL でページネーションしたいアイテムの一覧
- Connection ラッパー -- アプリケーションオブジェクトをラップし、GraphQL が利用するメソッドを実装するもの
- Connection Type -- connection 規約に準拠する GraphQL のオブジェクトタイプ

この例では、アプリケーションが外部の検索エンジンと通信し、すべての検索結果を `SearchEngine::Result` クラスで表現していると仮定します。（実際にそのようなクラスがあるわけではなく、アプリケーション固有のアイテム集合の任意の例です。）

## アプリケーションオブジェクト

Ruby では、すべてがオブジェクトであり、オブジェクトの「一覧」もオブジェクトに含まれます。たとえば Array はオブジェクトの一覧として考えられますが、Array 自体も独立したオブジェクトです。

一部の一覧オブジェクトは非常に洗練された実装を持ちます。`ActiveRecord::Relation` を考えてみてください：SQL クエリの構成要素を集め、適切なタイミングでデータベースにアクセスして一覧内のオブジェクトを取得します。`ActiveRecord::Relation` も一覧オブジェクトの一種です。

アプリケーションには、GraphQL の connection を通してページネーションしたい他の一覧オブジェクトが存在するはずです。たとえば、ユーザーに検索結果やファイルサーバー上のファイル一覧を表示する場合などです。これらの一覧は一覧オブジェクトとしてモデル化され、それらを Connection ラッパーで包むことができます。

## Connection ラッパー

Connection ラッパーは、通常の Ruby の一覧オブジェクト（Array、Relation、または `SearchEngine::Result` のようなアプリケーション固有のもの）と GraphQL の connection type の間のアダプタです。Connection ラッパーは、GraphQL の connection type が要求するメソッドを実装し、それらのメソッドを基になる一覧オブジェクトに基づいて実装します。

カスタム Connection ラッパーを作成するには、まず [`GraphQL::Pagination::Connection`](https://graphql-ruby.org/api-doc/GraphQL::Pagination::Connection) を継承して開始できます。たとえば次のようにします:

```ruby
# app/graphql/connections/search_results_connection.rb
class Connections::SearchResultsConnection < GraphQL::Pagination::Connection
  # implementation here ...
end
```

実装しなければならないメソッドは次のとおりです:

- `#nodes` — 指定された引数に基づいて `@items` のページネートされたスライスを返します
- `#has_next_page` — `#nodes` の後にアイテムがある場合に `true` を返します
- `#has_previous_page` — `#nodes` の前にアイテムがある場合に `true` を返します
- `#cursor_for(item)` — `item` のカーソルとして使う文字列を返します

これらのメソッドを（効率的に）どのように実装するかは、バックエンドやその通信方法に依存します。参考として、組み込みの connections を参照できます:

- [`GraphQL::Pagination::ArrayConnection`](https://graphql-ruby.org/api-doc/GraphQL::Pagination::ArrayConnection)
- [`GraphQL::Pagination::ActiveRecordRelationConnection`](https://graphql-ruby.org/api-doc/GraphQL::Pagination::ActiveRecordRelationConnection)
- [`GraphQL::Pagination::SequelDatasetConnection`](https://graphql-ruby.org/api-doc/GraphQL::Pagination::SequelDatasetConnection)
- [`GraphQL::Pagination::MongoidRelationConnection`](https://graphql-ruby.org/api-doc/GraphQL::Pagination::MongoidRelationConnection)

### カスタム Connection の使用

カスタム Connection ラッパーを GraphQL に統合するには、次の 2 つの方法があります:

- ラッパーをスキーマレベルであるクラスの一覧オブジェクトにマッピングし、それらの一覧オブジェクトが常に自動的にラップされるようにする；または
- リゾルバ内で手動でラッパーを使用して、自動マッピングをオーバーライドする

前者はとても便利で、後者は特定の状況に応じてカスタマイズすることを可能にします。

クラスにラッパーをマップするには、スキーマに追加します:

```ruby
class MySchema < GraphQL::Schema
  # Hook up a custom wrapper
  connections.add(SearchEngine::Result, Connections::SearchResultsConnection)
end
```

これにより、フィールドが `SearchEngine::Result` のインスタンスを返すたびに、それは `Connections::SearchResultsConnection` でラップされます。

あるいは、リゾルバ（メソッドまたは [`GraphQL::Schema::Resolver`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Resolver)）でケースバイケースにラッパーを適用することもできます:

```ruby
field :search, Types::SearchResult.connection_type, null: false do
  argument :query, String
end

def search(query:)
  search = SearchEngine::Search.new(query: query, viewer: context[:current_user])
  results = search.results
  # Apply the connection wrapper and return it
  Connections::SearchResultsConnection.new(results)
end
```

この場合、GraphQL-Ruby は提供された Connection ラッパーを使用します。この詳細なアプローチを使えば、特別なケースの処理やパフォーマンス最適化を実装できます。

## Connection Type

Connection Type は [Relay connection 仕様](https://relay.dev/graphql/connections.htm) に準拠する GraphQL のオブジェクトタイプです。GraphQL-Ruby には、これらのオブジェクトタイプを作成するためのツールが用意されています:

- [`GraphQL::Types::Relay::BaseConnection`](https://graphql-ruby.org/api-doc/GraphQL::Types::Relay::BaseConnection) と [`GraphQL::Types::Relay::BaseEdge`](https://graphql-ruby.org/api-doc/GraphQL::Types::Relay::BaseEdge) は仕様の実装例です。ただし、これらはアプリケーションのベースオブジェクトクラスを継承していないため、そのままでは使えないことがあります。
- 各 Type クラスは `.connection_type` に応答し、そのクラスに基づく生成済みの connection type を返します。デフォルトでは `GraphQL::Types::Relay::BaseConnection` から継承しますが、ベースクラスに `connection_type_class(Types::MyBaseConnectionObject)` を設定することで上書きできます。

たとえば、ベースの connection クラスを実装できます:

```ruby
class Types::BaseConnectionObject < Types::BaseObject
  # implement based on `GraphQL::Types::Relay::BaseConnection`, etc
end
```

そして、それをベースクラスに接続します:

```ruby
class Types::BaseObject < GraphQL::Schema::Object
  # ...
  connection_type_class(Types::BaseConnectionObject)
end

class Types::BaseUnion < GraphQL::Schema::Union
  connection_type_class(Types::BaseConnectionObject)
end

module Types::BaseInterface
  include GraphQL::Schema::Interface

  connection_type_class(Types::BaseConnectionObject)
end
```

その後、フィールド定義で `.connection_type` を使って接続クラスの階層を利用できます:

```ruby
field :posts, Types::Post.connection_type, null: false
```

（これらのフィールドは、生成された connection type の名前が `*Connection` で終わるため、デフォルトで `connection: true` になります。）
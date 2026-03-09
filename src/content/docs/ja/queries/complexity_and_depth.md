---
title: 複雑度と深さ
description: クエリの深さとフィールド選択の制限
sidebar:
  order: 4
---
GraphQL-Ruby は [query analysis](/queries/ast_analysis) に基づくいくつかのバリデーションを同梱しています。必要に応じてカスタマイズすることもできます。

## 深くネストされた query を防ぐ

ネストの深さに基づいて query を拒否することもできます。`max_depth` は schema レベルまたは query レベルで定義できます:

```ruby
# Schema-level:
class MySchema < GraphQL::Schema
  # ...
  max_depth 15
end

# Query-level, which overrides the schema-level setting:
MySchema.execute(query_string, max_depth: 20)
```

デフォルトでは、**introspection fields がカウントされます**。標準の introspection query は少なくとも `max_depth 13` を必要とします。`max_depth ..., count_introspection_fields: false` を使って、schema が introspection fields をカウントしないように設定することもできます。

検証を無効にするには `nil` を使います:

```ruby
# This query won't be validated:
MySchema.execute(query_string, max_depth: nil)
```

システム内の query の深さの傾向を掴むには、[`GraphQL::Analysis::QueryDepth`](https://graphql-ruby.org/api-doc/GraphQL::Analysis::QueryDepth) を拡張して、各 query から値をログ出力するようにできます:

```ruby
class LogQueryDepth < GraphQL::Analysis::QueryDepth
  def result
    query_depth = super
    message = "[GraphQL Query Depth] #{query_depth} || staff?  #{query.context[:current_user].staff?}"
    Rails.logger.info(message)
  end
end

class MySchema < GraphQL::Schema
  query_analyzer(LogQueryDepth)
end
```

## 複雑な query を防ぐ

field には定義時に「complexity」値を設定できます。これは定数（数値）でも proc でも可能です。field に `complexity` が定義されていない場合、デフォルトは `1` になります。`complexity` はキーワードとしても、設定ブロック内でも定義できます。例えば:

```ruby
# Constant complexity:
field :top_score, Integer, null: false, complexity: 10

# Dynamic complexity:
field :top_scorers, [PlayerType], null: false do
  argument :limit, Integer, limit: false, default_value: 5
  complexity ->(ctx, args, child_complexity) {
    if ctx[:current_user].staff?
      # no limit for staff users
      0
    else
      # `child_complexity` is the value for selections
      # which were made on the items of this list.
      #
      # We don't know how many items will be fetched because
      # we haven't run the query yet, but we can estimate by
      # using the `limit` argument which we defined above.
      args[:limit] * child_complexity
    end
  }
end
```

その上で、`max_complexity` を schema レベルで定義します:

```ruby
class MySchema < GraphQL::Schema
  # ...
  max_complexity 100
end
```

または、schema レベルの設定をオーバーライドする query レベルで:

```ruby
MySchema.execute(query_string, max_complexity: 100)
```

`nil` を使うとバリデーションを無効にできます:

```ruby
# 😧 Anything goes!
MySchema.execute(query_string, max_complexity: nil)
```

システム内の query の複雑度の傾向を掴むには、[`GraphQL::Analysis::QueryComplexity`](https://graphql-ruby.org/api-doc/GraphQL::Analysis::QueryComplexity) を拡張して、各 query から計算された値をログ出力するようにできます:

```ruby
class LogQueryComplexityAnalyzer < GraphQL::Analysis::QueryComplexity
  # Override this method to _do something_ with the calculated complexity value
  def result
    complexity = super
    message = "[GraphQL Query Complexity] #{complexity} | staff? #{query.context[:current_user].staff?}"
    Rails.logger.info(message)
  end
end

class MySchema < GraphQL::Schema
  query_analyzer(LogQueryComplexityAnalyzer)
end
```

デフォルトでは、**introspection fields がカウントされます**。`max_complexity ..., count_introspection_fields: false` を使って、schema が introspection fields をカウントしないように設定することもできます。

#### Connection fields の扱い

デフォルトでは、GraphQL-Ruby は connection fields に対して次のように complexity 値を計算します:

- `pageInfo` とその各サブセレクションに対して `1` を加算する
- `count`, `totalCount`, または `total` に対して `1` を加算する
- connection field 自体に対して `1` を加算する
- その他のフィールドの複雑度に対しては、最大のページサイズ（`first:` と `last:` のうち大きい方、またはどちらも与えられていない場合は `default_page_size`、schema の `default_page_size`、`max_page_size`、schema の `default_max_page_size` の順に調べて得られる値）を乗算する

    （デフォルトの page size や max page size が判定できない場合、解析は内部エラーでクラッシュします — これを防ぐには schema に `default_page_size` または `default_max_page_size` を設定してください。）

例えば、次の query は複雑度 `26` になります:

```graphql
query {
  author {              # +1
    name                # +1
    books(first: 10) {  # +1
      nodes {           # +10 (+1, multiplied by `first:` above)
        title           # +10 (ditto)
      }
      pageInfo {        # +1
        endCursor       # +1
      }
      totalCount        # +1
    }
  }
}
```

この挙動をカスタマイズするには、ベースの field クラスに `def calculate_complexity(query:, nodes:, child_complexity:)` を実装し、`self.connection?` が `true` の場合を処理してください:

```ruby
class Types::BaseField < GraphQL::Schema::Field
  def calculate_complexity(query:, nodes:, child_complexity:)
    if connection?
      # Custom connection calculation goes here
    else
      super
    end
  end
end
```

## 複雑度スコアの仕組み

GraphQL Ruby の複雑度スコアリングアルゴリズムは、選択の公平性に重きを置いています。非常に精度は高いものの、結果が直感に必ずしも一致するとは限りません。以下は [Shopify Admin API](https://shopify.dev/docs/api/admin-graphql) 上で行った例です:

```graphql
query {
  node(id: "123") { # interface Node
    id
    ...on HasMetafields { # interface HasMetafields
      metafield(key: "a") {
        value
      }
      metafields(first: 10) {
        nodes {
          value
        }
      }
    }
    ...on Product { # implements HasMetafields
      title
      metafield(key: "a") {
        definition {
          description
        }
      }
    }
    ...on PriceList {
      name
      catalog {
        id
      }
    }
  }
}
```

まず、GraphQL Ruby は field 定義が各 field の complexity スコア（またはスコアを計算する proc）を指定できるようにします。ここでは仮に次のようなルールがあるとします:

- リーフ field はコスト `0`
- 合成（composite）field はコスト `1`
- connection field は `children * input size` のコスト

これらのパラメータに基づく項目別のスコア配分は次のようになります:

```graphql
query {
  node(id: "123") { # 1, composite
    id # 0, leaf
    ...on HasMetafields {
      metafield(key: "a") { # 1, composite
        value # 0, leaf
      }
      metafields(first: 10) { # 1 * 10, connection
        nodes { # 1, composite
          value # 0, leaf
        }
      }
    }
    ...on Product {
      title # 0, leaf
      metafield(key: "a") { # 1, composite
        definition { # 1, composite
          description # 0, leaf
        }
      }
    }
    ...on PriceList {
      name # 0, leaf
      catalog { # 1, composite
        id # 0, leaf
      }
    }
  }
}
```

しかし、これらの項目別スコアを単純に合計するとクエリを過大に評価してしまいます。考慮すべき点は次のとおりです:

- `node` のスコープは抽象型に対して多くの「可能な」選択を生むので、公平に表現するには具象の可能性のうち最大値を取る必要がある
- `node.metafield` の選択パスは `HasMetafields` と `Product` の両方の選択スコープに重複して現れる。実際にはこのパスは一度だけ解決されるので、コストも一度だけにすべきである

これらを調整するために、[complexity algorithm](https://github.com/rmosolgo/graphql-ruby/blob/master/lib/graphql/analysis/query_complexity.rb) は選択を、可能な選択にマップされた型のツリーへと分解し、字句上の選択を併合・重複除去します（疑似コード）:

```ruby
{
  Schema::Query => {
    "node" => {
      Schema::Node => {
        "id" => nil,
      },
      Schema::HasMetafields => {
        "metafield" => {
          Schema::Metafield => {
            "value" => nil,
          },
        },
        "metafields" => {
          Schema::Metafield => {
            "nodes" => { ... },
          },
        },
      },
      Schema::Product => {
        "title" => nil,
        "metafield" => {
          Schema::Metafield => {
            "definition" => { ... },
          },
        },
      },
      Schema::PriceList => {
        "name" => nil,
        "catalog" => {
          Schema::Catalog => {
            "id" => nil,
          },
        },
      },
    },
  },
}
```

この集約により、個々の field ではなく「可能な型に対する選択」がコストを持つという新しい視点が得られます。この正規化されたビューでは、`Product` は `HasMetafields` のコストを取り込み、重複するパスを無視します。最終的に、可能な型ごとの最大コストが使われ、この query はコスト `12` になります:

```graphql
query {
  node(id: "123") { # max(11, 12, 1) = 12
    id
    ...on HasMetafields { # 1 + 10 = 11
      metafield(key: "a") { # 1
        value
      }
      metafields(first: 10) { # 10
        nodes {
          value
        }
      }
    }
    ...on Product { # 1 + 11 from HasMetafields = 12
      title
      metafield(key: "a") { # duplicated in HasMetafields
        definition { # 1
          description
        }
      }
    }
    ...on PriceList { # 1 = 1
      name
      catalog { # 1
        id
      }
    }
  }
}
```
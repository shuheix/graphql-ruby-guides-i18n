---
title: Lazy 実行
description: Resolversは、バッチ解決のために遅延される「未完了」の結果を返すことができます。
sidebar:
  order: 4
---
Lazy 実行では、一括呼び出しを行うことで外部サービス（例：データベース）へのアクセスを最適化できます。lazy loaderを構築するには、次の3つの手順があります。

- 値を読み込み返すメソッドを_1つ_だけ持つlazy loaderクラスを定義します
- これを schema に接続するには、[`GraphQL::Schema.lazy_resolve`](https://graphql-ruby.org/api-doc/GraphQL::Schema.lazy_resolve) を使用します
- `resolve` メソッド内で、lazy loaderクラスのインスタンスを返します

## 例：一括取得

以下は、IDで多数のオブジェクトを1回のデータベース呼び出しで取得し、N+1クエリを防ぐ方法です。

1. IDでモデルを検索するlazy loaderクラス。

```ruby
class LazyFindPerson
  def initialize(query_ctx, person_id)
    @person_id = person_id
    # Initialize the loading state for this query,
    # or get the previously-initiated state
    @lazy_state = query_ctx[:lazy_find_person] ||= {
      pending_ids: Set.new,
      loaded_ids: {},
    }
    # Register this ID to be loaded later:
    @lazy_state[:pending_ids] << person_id
  end

  # Return the loaded record, hitting the database if needed
  def person
    # Check if the record was already loaded:
    loaded_record = @lazy_state[:loaded_ids][@person_id]
    if loaded_record
      # The pending IDs were already loaded,
      # so return the result of that previous load
      loaded_record
    else
      # The record hasn't been loaded yet, so
      # hit the database with all pending IDs
      pending_ids = @lazy_state[:pending_ids].to_a
      people = Person.where(id: pending_ids)
      people.each { |person| @lazy_state[:loaded_ids][person.id] = person }
      @lazy_state[:pending_ids].clear
      # Now, get the matching person from the loaded result:
      @lazy_state[:loaded_ids][@person_id]
    end
  end
```

2. lazy resolve メソッドを接続する

```ruby
class MySchema < GraphQL::Schema
  # ...
  lazy_resolve(LazyFindPerson, :person)
end
```

3. `resolve` から lazy オブジェクトを返す

```ruby
field :author, PersonType

def author
  LazyFindPerson.new(context, object.author_id)
end
```

これで、`author` への呼び出しは一括されたデータベースアクセスを使用するようになります。たとえば、次のクエリは：

```graphql
{
  p1: post(id: 1) { author { name } }
  p2: post(id: 2) { author { name } }
  p3: post(id: 3) { author { name } }
}
```

`author` の値をロードするために、データベースへのクエリは1回だけ行われます。

## バッチ処理向けのGem

上の例は単純で、いくつかの欠点があります。堅牢なバッチ解決のためには、次のGemを検討してください。

* [`GraphQL::Dataloader`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader) は組み込みの、Fiberベースのバッチ処理アプローチです。詳細は [Dataloaderガイド](/dataloader/overview) を参照してください。
* [`graphql-batch`](https://github.com/shopify/graphql-batch) は、GraphQLでのlazy resolutionのための強力で柔軟なツールキットを提供します。
* [`dataloader`](https://github.com/sheerun/dataloader) は、同一スレッド内でのクエリをバッチ処理するための、より汎用的なPromiseベースのユーティリティです。
* [`batch-loader`](https://github.com/exAspArk/batch-loader) はGraphQLを含む任意のRubyコードで動作し、追加の依存関係やプリミティブを必要としません。
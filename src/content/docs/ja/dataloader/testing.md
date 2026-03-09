---
title: テスト
description: Dataloader 実装をテストするためのヒント
sidebar:
  order: 4
---
`[`GraphQL::Dataloader`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader)` のセットアップをテストするためのいくつかの手法があります。

## 統合テスト

`Dataloader` の重要な機能のひとつは、GraphQL がクエリを実行している間のデータベースアクセスの管理方法です。これをテストするには、クエリ実行中にデータベースクエリを監視します。たとえば ActiveRecord を使って次のように行います:

```ruby
def test_active_record_queries_are_batched_and_cached
  # set up a listener function
  database_queries = 0
  callback = lambda {|_name, _started, _finished, _unique_id, _payload| database_queries += 1 }

  query_str = <<-GRAPHQL
  {
    a1: author(id: 1) { name }
    a2: author(id: 2) { name }
    b1: book(id: 1) { author { name } }
    b2: book(id: 2) { author { name } }
  }
  GRAPHQL

  # Run the query with the listener
  ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
    MySchema.execute(query_str)
  end

  # One query for authors, one query for books
  assert_equal 2, database_queries
end
```

実行されるクエリに対して具体的なアサーションを行うこともできます（[`sql.active_record` ドキュメント](https://edgeguides.rubyonrails.org/active_support_instrumentation.html#active-record) を参照）。他のフレームワークやデータベースの場合は、ORM やライブラリの計測オプションを確認してください。

## Dataloader Source のテスト

GraphQL 外で `Dataloader` の動作を、[`GraphQL::Dataloader.with_dataloading`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader.with_dataloading) を使ってテストすることもできます。例えば、次のように `Sources::ActiveRecord` の source を定義しているとします:

```ruby

module Sources
  class User < GraphQL::Dataloader::Source
    def fetch(ids)
      records = User.where(id: ids)
      # return a list with `nil` for any ID that wasn't found, so the shape matches
      ids.map { |id| records.find { |r| r.id == id.to_i } }
    end
  end
end
```

次のようにテストできます:

```ruby
def test_it_fetches_objects_by_id
  user_1, user_2, user_3 = 3.times.map { User.create! }

  database_queries = 0
  callback = lambda {|_name, _started, _finished, _unique_id, _payload| database_queries += 1 }

  ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
    GraphQL::Dataloader.with_dataloading do |dataloader|
      req1 = dataloader.with(Sources::ActiveRecord).request(user_1.id)
      req2 = dataloader.with(Sources::ActiveRecord).request(user_2.id)
      req3 = dataloader.with(Sources::ActiveRecord).request(user_3.id)
      req4 = dataloader.with(Sources::ActiveRecord).request(-1)

      # Validate source's matching up of records
      expect(req1.load).to eq(user_1)
      expect(req2.load).to eq(user_2)
      expect(req3.load).to eq(user_3)
      expect(req4.load).to be_nil
    end
  end

  assert_equal 1, database_queries, "All users were looked up at once"
end
```
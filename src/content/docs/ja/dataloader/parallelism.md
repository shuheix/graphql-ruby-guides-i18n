---
title: 手動並列処理
description: 作業開始後にDataloaderへ制御を戻す
sidebar:
  order: 7
---
[`GraphQL::Dataloader`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader) と連携してタスクをバックグラウンドで実行できます。これを行うには、作業を開始した後に `Source#fetch` 内で `dataloader.yield` を呼び出します。例えば:

```ruby
def fetch(ids)
  # somehow queue up a background query,
  # see examples below
  future_result = async_query_for(ids)
  # return control to the dataloader
  dataloader.yield
  # dataloader will come back here
  # after calling other sources,
  # now wait for the value
  future_result.value
end
```

_代わりに、`Source#fetch` の呼び出し内で自動的に I/O をバックグラウンド化するには [AsyncDataloader](/dataloader/async_dataloader) を使用できます。_

## 例: Rails の load_async

Rails の `load_async` メソッドを使って `ActiveRecord::Relation` をバックグラウンドでロードできます。例えば:

```ruby
class Sources::AsyncRelationSource < GraphQL::Dataloader::Source
  def fetch(relations)
    relations.each(&:load_async) # start loading them in the background
    dataloader.yield # hand back to GraphQL::Dataloader
    relations.each(&:load) # now, wait for the result, returning the now-loaded relation
  end
end
```

その source を GraphQL の field メソッドから呼び出せます:

```ruby
field :direct_reports, [Person]

def direct_reports
  # prepare an ActiveRecord::Relation:
  direct_reports = Person.where(manager: object)
  # pass it off to the source:
  dataloader
    .with(Sources::AsyncRelationSource)
    .load(direct_reports)
end
```

## 例: Rails の非同期計算

Dataloader の source 内では、他の処理が続行されている間に Rails の非同期計算をバックグラウンドで実行できます。例えば:

```ruby
class Sources::DirectReportsCount < GraphQL::Dataloader::Source
  def fetch(users)
    # Start the queries in the background:
    promises = users.map { |u| u.direct_reports.async_count }
    # Return to GraphQL::Dataloader:
    dataloader.yield
    # Now return the results, waiting if necessary:
    promises.map(&:value)
  end
end
```

これは GraphQL の field で次のように使用できます:

```ruby
field :direct_reports_count, Int

def direct_reports_count
  dataloader.with(Sources::DirectReportsCount).load(object)
end
```

## 例: Concurrent::Future

`concurrent-ruby` を使って処理をバックグラウンドスレッドに配置できます。例えば `Concurrent::Future` を使う場合:

```ruby
class Sources::ExternalDataSource < GraphQL::Dataloader::Source
  def fetch(urls)
    # Start some I/O-intensive work:
    futures = urls.map do |url|
      Concurrent::Future.execute {
        # Somehow fetch and parse data:
        get_remote_json(url)
      }
    end
    # Yield back to GraphQL::Dataloader:
    dataloader.yield
    # Dataloader has done what it can,
    # so now return the value, waiting if necessary:
    futures.map(&:value)
  end
end
```
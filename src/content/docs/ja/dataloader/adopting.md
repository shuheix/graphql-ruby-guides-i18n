---
title: Dataloader と GraphQL-Batch の比較
description: バッチローディングのオプションの比較
sidebar:
  order: 3
---
[`GraphQL::Dataloader`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader) は [`GraphQL::Batch`](https://github.com/shopify/graphql-batch) と同じ問題を解決します。これらのモジュールにはいくつか大きな違いがあります:

- __並行処理プリミティブ:__ GraphQL-Batch は [`promise.rb`](https://github.com/lgierth/promise.rb) の `Promise` を使います。GraphQL::Dataloader は Ruby の [`Fiber` API](https://ruby-doc.org/core-3.0.0/Fiber.html) を使います。これらのプリミティブによってバッチローディングのコードの書き方が決まります（比較は以下を参照してください）。
- __成熟度:__ 率直に言うと、GraphQL-Batch は GraphQL-Ruby とほぼ同じ歴史があり、Shopify、GitHub などで長年本番運用されています。GraphQL::Dataloader は新しく、Ruby は 1.9 から `Fiber` をサポートしていますが、まだ広く使われているわけではありません。
- __スコープ:__ 現時点では `GraphQL::Dataloader` を _GraphQL の外で_ 使用することはできません。

`GraphQL::Dataloader` を作成した動機は、`Fiber` が作業を _透過的に_ 一時停止・再開できる点を活かすことで、`Promise` の必要性（およびそれに伴うコードの複雑さ）を無くすことにありました。加えて、`GraphQL::Dataloader` は最終的に Ruby 3.0 の `Fiber.scheduler` API をサポートする予定で、これにより I/O がデフォルトでバックグラウンドで実行されます。

## 比較: 単一オブジェクトの取得

この例では、GraphQL の field を満たすために単一のオブジェクトをバッチロードします。

- __GraphQL-Batch__ では、loader を呼び出すと `Promise` が返されます:

  ```ruby
  record_promise = Loaders::Record.load(1)
  ```

  その後、内部では GraphQL-Ruby が（かつて GraphQL-Batch から取り込まれた）`lazy_resolve` 機能を使ってこの promise を管理します。GraphQL-Ruby はもはや実行できる処理がないときにその上で `.sync` を呼び出します。`promise.rb` は保留中の作業を実行するために `Promise#sync` を実装しています。

- __GraphQL::Dataloader__ では、まず source を取得し、`.load` を呼ぶと（現在の Fiber を一時停止する可能性はありますが）要求したオブジェクトが返されます。

  ```ruby
  dataloader.with(Sources::Record).load(1)
  ```

  `.load` から要求したオブジェクトが（最終的に）返されるため、それ以外の処理は不要です。

## 比較: 依存関係のある順次取得

この例では、まずあるオブジェクトをロードし、そのオブジェクトに基づいて別のオブジェクトをロードします。

- __GraphQL-Batch__ では、依存するコードブロックを結合するために `.then { ... }` を使います:

  ```ruby
  Loaders::Record.load(1).then do |record|
    Loaders::OtherRecord.load(record.other_record_id)
  end
  ```

  この呼び出しは `Promise` を返し、GraphQL-Ruby によって保持され、最後に `.sync` されます。

- __GraphQL::Dataloader__ では、`.load(...)` が（必要に応じて Fiber を一時停止した後で）要求したオブジェクトを返すため、他のメソッド呼び出しは不要です:

  ```ruby
  record = dataloader.with(Sources::Record).load(1)
  dataloader.with(Sources::OtherRecord).load(record.other_record_id)
  ```

## 比較: 独立した複数オブジェクトの同時取得

計算を行うために複数の独立したレコードが必要になることがあります。各レコードをロードしてから、それらを組み合わせて処理します。

- __GraphQL-Batch__ では、複数の保留中ロードを待つために `Promise.all(...)` を使います:

  ```ruby
  promise_1 = Loaders::Record.load(1)
  promise_2 = Loaders::OtherRecord.load(2)
  Promise.all([promise_1, promise_2]).then do |record, other_record|
    do_something(record, other_record)
  end
  ```

  同じ loader からオブジェクトを取得する場合は、`.load_many` も使えます:

  ```ruby
  Loaders::Record.load_many([1, 2]).then do |record, other_record|
    do_something(record, other_record)
  end
  ```

- __GraphQL::Dataloader__ では、各リクエストを `.request(...)` で登録し（この呼び出しは Fiber を一切一時停止しません）、その後 `.load` でデータを読み込みます（必要に応じて Fiber を一時停止します）:

  ```ruby
  # first, make some requests
  request_1 = dataloader.with(Sources::Record).request(1)
  request_2 = dataloader.with(Sources::OtherRecord).request(2)
  # then, load the objects and do something
  record = request_1.load
  other_record = request_2.load
  do_something(record, other_record)
  ```

  もしオブジェクトが同じ `Source` から来るなら、`.load_all` はオブジェクトを直接返します:

  ```ruby
  record, other_record = dataloader.with(Sources::Record).load_all([1, 2])
  do_something(record, other_record)
  ```

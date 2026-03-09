---
title: Redis の設定
description: レートリミッタのバックエンドの準備
sidebar:
  order: 1
enterprise: true
---
レート制限には永続的な Redis インスタンスが必要です。これは [Sidekiq](https://github.com/mperham/sidekiq/wiki/Using-Redis) や [Operation Store](/operation_store/redis_backend) と同様です。Redis がメモリ制限に達した際にキーを自動的に破棄しないようにするには、`redis.conf` に `maxmemory-policy noeviction` を設定してください。

## メモリ使用量

メモリ使用量の見積りは、Redis キーに使われるクライアント識別文字列によります。100 文字のクライアントキーを使う場合、runtime limiter はクライアントごとに 400 バイト（キーが 2 つ）を使用します。active operation limiter のメモリ使用量は制限値に依存します。並行処理ごとにメモリを消費するため、制限値が高いほど同時実行数が増えます。たとえば、アクティブな操作が 10 件で 100 文字のクライアントキーを使うと、active operation limiter はクライアントごとに 350 バイトを使用します。加えて、ダッシュボードのために最大 35kb を使用します（リミッタが 2 つあり、それぞれについて: 2×60 個の 1 分単位のキー、24 個の時間単位のキー、30 個の日次キー、各キーは 72 バイト）。

これらの推定により、1 GB のメモリがあれば、両方のレートリミッタで約 140 万以上のアクティブクライアントをサポートできる計算になります。

## 接続プール

ActiveOperationsLimiter と RuntimeLimiter は [ConnectionPool](https://github.com/mperham/connection_pool) をサポートします。使用するには `connection_pool:` を渡してください:

```ruby
use GraphQL::Enterprise::RuntimeLimiter, # or ActiveOperationLimiter
  connection_pool: ConnectionPool.new(...) { ... }
  # ...
```

## Redis クラスタ

ActiveOperationsLimiter と RuntimeLimiter は [`redis-cluster`](https://github.com/redis/redis-rb/tree/master/cluster) をサポートします。使用するには `redis_cluster:` を渡してください:

```ruby
use GraphQL::Enterprise::RuntimeLimiter, # or ActiveOperationLimiter
  redis_cluster: Redis::Cluster.new(...)
  # ...
```
---
title: Redis の設定
description: Redis バックエンドの設定
sidebar:
  order: 3
enterprise: true
---
`GraphQL::Enterprise::ObjectCache` は、cacheされたレスポンスを保存するために Redis への接続を必要とします。`OperationStore` やレートリミッターと異なり、この Redis インスタンスは必要に応じてキーを削除するよう設定する必要があります。

## メモリ管理

メモリ使用量は、cache が受ける queries の数、それらの queries が参照する objects の数、それらの queries に対するレスポンスの大きさ、および各 object と query の fingerprints の長さに依存するため、推定が難しいです。メモリを管理するには、Redis インスタンスに `maxmemory` と `maxmemory-policy` のディレクティブを設定してください。例えば：

```
maxmemory 1gb
maxmemory-policy allkeys-lfu
```

また、最も重要な GraphQL トラフィックを優先するために、条件に応じて cache をスキップすることを検討してください。

## Redis クラスター

`ObjectCache` は Redis クラスターもサポートしています。利用するには、`redis_cluster:` を渡してください：

```ruby
use GraphQL::Enterprise::ObjectCache, redis_cluster: Redis::Cluster.new(...)
```

内部では、query の fingerprints を [ハッシュタグ](https://redis.io/docs/latest/operate/oss_and_stack/reference/cluster-spec/#hash-tags) として使用し、各 cache 結果は独自の object メタデータセットを持ちます。

## コネクションプール

`ObjectCache` は [ConnectionPool](https://github.com/mperham/connection_pool) もサポートしています。使用するには、`connection_pool:` を渡してください：

```ruby
use GraphQL::Enterprise::ObjectCache, connection_pool: ConnectionPool.new(...) { ... }
```

## データ構造

内部では、`ObjectCache` は queries と objects のマッピングを保存します。さらに、objects からそれらを参照する queries への逆参照も保持します。概略は次の通りです：

```
"query1:result" => '{"data":{...}}'
"query1:objects" => ["obj1:v1", "obj2:v2"]

"query2:result" => '{"data":{...}}'
"query2:objects" => ["obj2:v2", "obj3:v1"]

"obj1:v1" => { "fingerprint" => "...", "id" => "...", "type_name" => "..." }
"obj2:v2" => { "fingerprint" => "...", "id" => "...", "type_name" => "..." }
"obj3:v1" => { "fingerprint" => "...", "id" => "...", "type_name" => "..." }

"obj1:v1:queries" => ["query1"]
"obj2:v2:queries" => ["query1", "query2"]
"obj3:v1:queries" => ["query2"]
```

これらのマッピングにより、queries や objects が cache から期限切れになった際に適切にクリーンアップできます。さらに、`ObjectCache` がストレージ内で不完全なデータ（例えば必要なキーが削除されている場合）を検出したときは、該当の query 全体を無効化して再実行します。
---
title: Dalli の設定
description: Memcached バックエンドの設定
sidebar:
  order: 3
enterprise: true
---
`GraphQL::Enterprise::ObjectCache` は [Dalli](https://github.com/petergoldstein/dalli) クライアント gem を使って、Memcached バックエンドでも動作します。

設定するには、`Dalli::Client` インスタンスを `dalli: ...` として渡します。例えば:

```ruby
use GraphQL::Enterprise::OperationStore, dalli: Dalli::Client.new(...)
```
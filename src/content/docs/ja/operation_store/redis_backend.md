---
title: Redis バックエンド
description: Redis で永続化されたクエリを保存する
sidebar:
  order: 3
pro: true
---
`OperationStore` は Redis を使って永続化されたクエリを保存できます。プラグインを追加する際に `redis:` オプションを渡してください:

```ruby
class MySchema < GraphQL::Schema
  use GraphQL::Pro::OperationStore, redis: Redis.new
end
```

（必要に応じて任意のオプションで `Redis` を初期化できます。）

__注意:__ この Redis インスタンスがキャッシュではなく、_永続的なデータベース_ として構成されていることを必ず確認してください。古いキーが破棄されてしまわないようにしてください。
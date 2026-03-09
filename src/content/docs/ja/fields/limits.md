---
title: 制限
description: リストの項目数は常に制限してください
sidebar:
  order: 4
---
## リストの field

常に、リスト field から返される項目数を制限してください。例えば、`limit:` 引数を使い、その値が大きすぎないようにします。アイテム数の上限を設定するには、`prepare:` 関数が便利です:

```ruby
field :items, [Types::ItemType] do
  # Cap the number of items at 30
  argument :limit, Integer, default_value: 20, prepare: ->(limit, ctx) {[limit, 30].min}
end

def items(limit:)
  object.items.limit(limit)
end
```

これにより、データベースに対して1000件分の問い合わせをしてしまうことを防げます。

## Connections の扱い

Connections はノード数を制限する [`max_page_size` オプション](/pagination/using_connections#max-page-size) を受け付けます。
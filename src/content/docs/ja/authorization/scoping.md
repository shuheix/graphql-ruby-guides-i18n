---
title: スコーピング
description: 現在のビューアーとコンテキストに合わせてリストをフィルタする
sidebar:
  order: 4
---
_Scoping_ は認可（authorization）に対する補完的な考慮事項です。単に「このユーザーはこの項目を見られるか？」をチェックするのではなく、scoping はアイテムのリストを現在のビューアーとコンテキストに適したサブセットに絞り込みます。

類似の機能については、[Pundit の scopes](https://github.com/varvet/pundit#scopes) および [Cancan の `.accessible_by`](https://github.com/CanCanCommunity/cancancan/blob/develop/docs/fetching_records.md) を参照してください。

## `scope:` オプション

Fields は `scope:` オプションを受け付け、スコーピングを有効（または無効）にできます。例:

```ruby
field :products, [Types::Product], scope: true
# Or
field :all_products, [Types::Product], scope: false
```

__list__ と __connection__ の field では、`scope: true` がデフォルトです。それ以外のすべての field では、`scope: false` がデフォルトです。`scope:` オプションでこれを上書きできます。

## `.scope_items(items, ctx)` メソッド

Type クラスは `.scope_items(items, ctx)` を実装できます。このメソッドは field が `scope: true` のときに呼び出されます。例えば、

```ruby
field :products, [Types::Product] # has `scope: true` by default
```

は次を呼び出します:

```ruby
class Types::Product < Types::BaseObject
  def self.scope_items(items, context)
    # filter items here
  end
end
```

このメソッドは現在の `context` に対して適切なアイテムだけを含む新しいリストを返すべきです。

## オブジェクトレベルの認可をバイパスする

`.scope_items` から返された任意のアイテムが現在のクライアントに対して表示されるべきであると分かっている場合は、型定義内で `reauthorize_scoped_objects(false)` を設定して通常の `.authorized?(obj, ctx)` チェックをスキップできます。例えば:

```ruby
class Types::Product < Types::BaseObject
  # Check that singly-loaded objects are visible to the current viewer
  def self.authorized?(object, context)
    super && object.visible_to?(context[:viewer])
  end

  # Filter any list to only include objects that are visible to the current viewer
  def self.scope_items(items, context)
    items = super(items, context)
    items.visible_for(context[:viewer])
  end

  # If an object of this type was returned from `.scope_items`,
  # don't call `.authorized?` with it.
  reauthorize_scoped_objects(false)
end
```
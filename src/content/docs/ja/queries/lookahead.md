---
title: Lookahead
description: fieldの解決中に子選択を検出する
sidebar:
  order: 11
---
GraphQL-Ruby 1.9+ には、子 field が選択されているかを確認するための [`GraphQL::Execution::Lookahead`](https://graphql-ruby.org/api-doc/GraphQL::Execution::Lookahead) が含まれています。これを使うとデータベースアクセスを最適化でき、例えばデータベースから必要な field のみを取得する、といったことが可能です。

## Lookahead を取得する

injected な lookahead を受け取るには、field の設定に `extras: [:lookahead]` を追加します:

```ruby
field :files, [Types::File], null: false, extras: [:lookahead]
```

次に、resolver メソッドを `lookahead:` 引数を受け取るように更新します:

```ruby
def files(lookahead:)
  # ...
end
```

この引数は GraphQL ランタイムによって注入されます。

## Lookahead の使用方法

field resolver 内で、lookahead を使って子 field の選択を確認できます。たとえば、特定の選択をチェックすることができます:

```ruby
def files(lookahead:)
  if lookahead.selects?(:full_path)
    # This is a query like `files { fullPath ... }`
  else
    # This query doesn't have `fullPath`
  end
end
```

あるいは、選択されたすべての field を列挙することもできます:

```ruby
def files(lookahead:)
  all_selections = lookahead.selections.map(&:name)
  if all_selections == [:name]
    # Only `files { name }` was selected, use a fast cached value:
    object.file_names.map { |n| { name: n }}
  else
    # Lots of fields were selected, fall back to a more resource-intensive approach
    FileSystemHelper.load_files_for(object)
  end
end
```

Lookahead はチェーン可能で、ネストされた選択の確認にも使えます:

```ruby
def files(lookahead:)
  if lookahead.selection(:history).selects?(:author)
    # For example, `files { history { author { ... } } }`
    # We're checking for commit authors, so load those objects appropriately ...
  else
    # Not selecting commit authors ...
  end
end
```

ネストされた lookahead は選択がない場合に空のオブジェクトを返す（`nil` ではない）ので、上記のコードで `nil` に対する「no method error」が発生することはありません。

## connection と Lookahead

connection 内のアイテムに対してどのような選択が行われたかを確認したい場合は、ネストされた lookahead を使えます。ただし、ショートカットフィールド `edges { node }` と `nodes { ... }` の両方をサポートしている場合は、両方をチェックするのを忘れないでください。例:

```ruby
field :products, Types::Product.connection_type, null: false, extras: [:lookahead]

def products(lookahead:)
  selects_quantity_available = lookahead.selection(:nodes).selects?(:quantity_available) ||
                               # ^^ check for `products { nodes { quantityAvailable } }`
    lookahead.selection(:edges).selection(:node).selects?(:quantity_available)
    # ^^ check for `products { edges { node { quantityAvailable } } }`

  if selects_quantity_available
    # ...
  else
    # ...
  end
end
```

このようにして、connection の node に対する特定の選択をチェックできます。

## エイリアス(alias) を使った Lookahead

選択をその [エイリアス](https://spec.graphql.org/June2018/#sec-Field-Alias) で見つけたい場合は、`#alias_selection(...)` を使うか、存在するかどうかを `#selects_alias?` で確認できます。この場合、lookahead は指定されたエイリアスを持つ field があるかどうかをチェックします。

たとえば、次のクエリは名前で鳥の種を取得できます:

```graphql
query {
  gull: findBirdSpecies(byName: "Laughing Gull") {
    name
  }

  tanager: findBirdSpecies(byName: "Scarlet Tanager") {
    name
  }
}
```

各選択に対する lookahead は次のように取得できます:

```ruby
def find_bird_species(by_name:, lookahead:)
  if lookahead.selects_alias?("gull")
    lookahead.alias_selection("gull")
  end
end
```
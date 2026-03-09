---
title: レスポンスの拡張
description: レスポンスのハッシュに "extensions" を追加する
sidebar:
  order: 12
---
query 実行中に、レスポンスの ` "extensions" => { ... } ` Hash に値を追加できます。デフォルトでは結果に ` "extensions" ` キーは含まれませんが、下のメソッドを呼び出すと指定した値で含まれるようになります。

` "extensions" ` に追加するには、実行中に `context.response_extensions[key] = value` を呼び出します。例えば:

```ruby
field :to_dos, [ToDo]

def to_dos
  warnings = context.response_extensions["warnings"] ||= []
  warnings << "To-Dos will be disabled on Jan. 31, 2022."
  context[:current_user].deprecated_to_dos
end
```

その結果、最終的な query レスポンスには次のように追加されます:

```ruby
{
  "data" => { ... },
  "extensions" => {
    "warnings" => ["To-Dos will be disabled on Jan. 31, 2022"],
  },
}
```

`context.response_extensions` に書き込まれた値は、そのまま GraphQL レスポンスに追加されます。
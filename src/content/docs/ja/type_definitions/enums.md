---
title: Enums
description: Enums は離散的な値の集合です
sidebar:
  order: 2
---
Enum types は離散的な値の集合です。Enum の field はその enum の可能な値のいずれかを返す必要があります。[GraphQL Schema Definition Language](https://graphql.org/learn/schema/#enum-types) (SDL) では、enum は次のように記述します:

```ruby
enum MediaCategory {
  AUDIO
  IMAGE
  TEXT
  VIDEO
}
```

したがって、`MediaCategory` の値は `AUDIO`、`IMAGE`、`TEXT`、または `VIDEO` のいずれかです。これは [ActiveRecord enums](https://api.rubyonrails.org/classes/ActiveRecord/Enum.html) に似ています。

GraphQL の query では、enum は文字列ではなく識別子として記述します。例えば:

```ruby
search(term: "puppies", mediaType: IMAGE) { ... }
```

(`IMAGE` に引用符が付いていないことに注意してください。)

ただし、GraphQL のレスポンスや変数が JSON で送られる場合、enum の値は文字列として表現されます。例えば:

```ruby
# in a graphql controller:
params["variables"]
# { "mediaType" => "IMAGE" }
```

## Enum Type の定義

アプリケーション内では、enums は [`GraphQL::Schema::Enum`](https://graphql-ruby.org/api-doc/GraphQL/Schema/Enum) を継承し、`value(...)` メソッドで値を定義します:

```ruby
# First, a base class
# app/graphql/types/base_enum.rb
class Types::BaseEnum < GraphQL::Schema::Enum
end

# app/graphql/types/media_category.rb
class Types::MediaCategory < Types::BaseEnum
  value "AUDIO", "An audio file, such as music or spoken word"
  value "IMAGE", "A still image, such as a photo or graphic"
  value "TEXT", "Written words"
  value "VIDEO", "Motion picture, may have audio"
end
```

各値には次のような属性を付けられます:

- 説明（第2引数として、または `description:` キーワードで）
- コメント（`comment:` キーワードで）
- 非推奨理由（`deprecation_reason:`） — この値を非推奨としてマークします
- 対応する Ruby の値（`value:`） — 以下を参照してください

デフォルトでは、Ruby の文字列は GraphQL の enum 値に対応します。しかし、`value:` オプションを指定して別のマッピングを与えることもできます。例えば、文字列の代わりにシンボルを使う場合は次のようにします:

```ruby
value "AUDIO", value: :audio
```

すると、GraphQL の入力としての `AUDIO` は `:audio` に変換され、Ruby 側の `:audio` は GraphQL のレスポンスでは `"AUDIO"` に変換されます。

Enum クラスはインスタンス化されず、そのメソッドも呼び出されません。

enum 値の GraphQL 名は、その小文字化された名前と一致するメソッドを使って取得できます:

```ruby
Types::MediaCategory.audio # => "AUDIO"
```

`value_method:` を渡して、生成されるメソッドの名前を上書きすることもできます:

```ruby
value "AUDIO", value: :audio, value_method: :lo_fi_audio

# ...

Types::MediaCategory.lo_fi_audio # => "AUDIO"
```

また、`value_method` を `false` に設定するとメソッド生成を完全にスキップできます。

```ruby
value "AUDIO", value: :audio, value_method: false
```
---
title: リスト
description: 他の type を含む順序付きのリスト
sidebar:
  order: 6
---
GraphQL には、他の type の要素を含む順序付きの list types が存在します。以下の例は [GraphQL スキーマ定義言語](https://graphql.org/learn/schema/#list) (SDL) を使用しています。

フィールドは単一の scalar 値（例: `String`）を返すことも、scalar 値の list（例: `[String]`、文字列のリスト）を返すこともできます。

```ruby
type Spy {
  # This spy's real name
  realName: String!
  # Any other names that this spy goes by
  aliases: [String!]
}
```

フィールドは他の type のリストを返すこともできます。

```ruby
enum PostCategory {
  SOFTWARE
  UPHOLSTERY
  MAGIC_THE_GATHERING
}

type BlogPost {
  # Zero or more categories this post belongs to
  categories: [PostCategory!]
  # Other posts related to this one
  relatedPosts: [BlogPost!]
}
```

入力でも list を使えます。引数は list type を受け取ることができます。例えば:

```ruby
type Query {
  # Return the latest posts, filtered by `categories`
  posts(categories: [PostCategory!]): [BlogPost!]
}
```

GraphQL を JSON で送受信する場合、GraphQL の lists は JSON の配列として表現されます。

見出し: Ruby における List Types

Ruby で list type を定義するには `[...]`（要素がひとつの Ruby 配列、内側の型）を使います。例えば:

```ruby
# A field returning a list type:
# Equivalent to `aliases: [String!]` above
field :aliases, [String]

# An argument which accepts a list type:
argument :categories, [Types::PostCategory], required: false
```

入力については、GraphQL の lists は Ruby の配列に変換されます。

list type を返すフィールドでは、`#each` に応答するオブジェクトであれば何でも返すことができます。それは GraphQL の list として列挙されます。

list の要素として `nil` を許容したい場合は、定義配列内で `null: true` を使います。例えば:

```ruby
# Equivalent to `previousEmployers: [Employer]!`
field :previous_employers, [Types::Employer, null: true], "Previous employers; `null` represents a period of self-employment or unemployment" null: false
```

見出し: Lists、Nullable Lists、Lists of Nulls

list types と non-null types を組み合わせるのは少しややこしい場合があります。2つのパラメータに基づいて4つの組み合わせが考えられます。

- フィールドのヌル許容性: このフィールドは `null` を返す可能性があるか、それとも常にリストを返すか？
- リスト要素のヌル許容性: リストが存在する場合、`null` を含む可能性があるか？

これらの組み合わせは次のようになります:

 &nbsp;  | nullable field | non-null field
 ------|------|------
nullable items  | <code>[Integer, null: true], null: true</code><br><code># => [Int]</code> | <code>[Integer, null: true], null: false</code><br><code># => [Int]!</code>
non-null items   | <code>[Integer]</code><br><code># => [Int!]</code> | <code>[Integer], null: false</code><br><code># => [Int!]!</code>

（1行目は GraphQL-Ruby のコードです。2行目の `# =>` で始まる行は対応する GraphQL SDL のコードです。）

いくつか例を見てみましょう。

見出し: Non-null lists with non-null items

例として次のフィールドを見ます。

```ruby
field :scores, [Integer], null: false
# In GraphQL,
#   scores: [Int!]!
```

この例では、`scores` は `null` を返すことができません。常にリストを返す必要があります。加えて、そのリストは決して `null` を含めてはいけません — 含められるのは `Int` のみです。（空であってもよいですが、`null` を含めることはできません。）

フィールドが返し得る値の例:

| Valid | Invalid |
| ------ | ------ |
| `[]` | `null` |
| `[1, 2, ...]` | `[null]` |
| | `[1, null, 2, ...]` |

見出し: Non-null lists with nullable items

例:

```ruby
field :scores, [Integer, null: true], null: false
# In GraphQL,
#   scores: [Int]!
```

この例では、`scores` は `null` を返すことができません。常にリストを返す必要があります。しかし、リストは `null` や `Int` を含んでも構いません。

フィールドが返し得る値の例:

Valid | Invalid
------|------
`[]`  | `null`
`[1, 2, ...]`|
`[null]` |
 `[1, null, 2, ...]` |

見出し: Nullable lists with nullable items

例:

```ruby
field :scores, [Integer, null: true]
# In GraphQL,
#   scores: [Int]
```

この例では、`scores` は `null` を返すこともリストを返すこともできます。加えて、そのリストは `null` や `Int` を含んでも構いません。

フィールドが返し得る値の例:

Valid | Invalid
------|------
`null` |
`[]`  |
`[1, 2, ...]`|
`[null]` |
 `[1, null, 2, ...]` |

見出し: Nullable lists with non-null items

例:

```ruby
field :scores, [Integer]
# In GraphQL,
#   scores: [Int!]
```

この例では、`scores` は `null` を返すこともリストを返すこともできます。ただし、リストが存在する場合には `null` を含めることはできず、`Int` のみを含む必要があります。

フィールドが返し得る値の例:

Valid | Invalid
------|------
`null` | `[null]`
`[]`  | `[1, null, 2, ...]`
`[1, 2, ...]` |
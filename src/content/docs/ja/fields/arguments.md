---
title: Arguments
description: Fields は入力として arguments を受け取ることができます
sidebar:
  order: 1
---
Fields は入力として **arguments** を受け取ることができます。これらは返り値を決定するため（例：検索結果のフィルタリング）やアプリケーションの状態を変更するため（例：`MutationType` でのデータベース更新）に使えます。

Arguments は `argument` ヘルパーで定義します。これらの arguments は resolver メソッドに [キーワード引数](https://robots.thoughtbot.com/ruby-2-keyword-arguments) として渡されます:

```ruby
field :search_posts, [PostType], null: false do
  argument :category, String
end

def search_posts(category:)
  Post.where(category: category).limit(10)
end
```

見出し: 引数の必須性

引数を任意にするには `required: false` を設定し、対応するキーワード引数のデフォルト値を設定します:

```ruby
field :search_posts, [PostType], null: false do
  argument :category, String, required: false
end

def search_posts(category: nil)
  if category
    Post.where(category: category).limit(10)
  else
    Post.all.limit(10)
  end
end
```

すべての arguments が任意で、クエリが引数を何も渡さない場合、resolver メソッドは引数なしで呼ばれる点に注意してください。この場合に `ArgumentError` を防ぐには、前の例のようにすべてのキーワード引数にデフォルト値を指定するか、メソッド定義でダブルスプラット演算子（double splat）を使う必要があります。例:

```ruby
def search_posts(**args)
  if args[:category]
    Post.where(category: args[:category]).limit(10)
  else
    Post.all.limit(10)
  end
end
```

見出し: デフォルト値

別の方法として、クエリで引数が指定されなかった場合に `default_value: value` を使ってデフォルト値を指定できます。

```ruby
field :search_posts, [PostType], null: false do
  argument :category, String, required: false, default_value: "Programming"
end

def search_posts(category:)
  Post.where(category: category).limit(10)
end
```

`required: false` の arguments はクライアントから `null` を受け取ることを許容します。resolver のコードでこれは意外になることがあり、例えば `Integer, required: false` の引数が `nil` になることがあります。この場合、`replace_null_with_default: true` を使うと、クライアントが `null` を送信したときに指定した `default_value: ...` が適用されます。例:

```ruby
# Even if clients send `query: null`, the resolver will receive `"*"` for this argument:
argument :query, String, required: false, default_value: "*", replace_null_with_default: true
```

最後に、`required: :nullable` はクライアントに引数の送信を要求しますが、`null` を有効な入力として受け入れます。例:

```ruby
# This argument _must_ be given -- send `null` if there's no other appropriate value:
argument :email_address, String, required: :nullable
```

見出し: 非推奨

実験的機能: __Deprecated__ な arguments は `deprecation_reason:` キーワード引数を追加してマークできます:

```ruby
field :search_posts, [PostType], null: false do
  argument :name, String, required: false, deprecation_reason: "Use `query` instead."
  argument :query, String, required: false
end
```

見出し: エイリアス

`as: :alternate_name` を使うと、クライアントに別名を公開しつつ、resolver 内部では別のキー名を使えます。

```ruby
field :post, PostType, null: false do
  argument :post_id, ID, as: :id
end

def post(id:)
  Post.find(id)
end
```

見出し: 前処理

`prepare` 関数を指定すると、field の resolver メソッドが実行される前に引数の値を変換・検証できます:

```ruby
field :posts, [PostType], null: false do
  argument :start_date, String, prepare: ->(startDate, ctx) {
    # return the prepared argument.
    # raise a GraphQL::ExecutionError to halt the execution of the field and
    # add the exception's message to the `errors` key.
  }
end

def posts(start_date:)
  # use prepared start_date
end
```

見出し: 自動キャメル化

snake_cased の arguments は GraphQL schema ではキャメル化されます。以下の例の場合:

```ruby
field :posts, [PostType], null: false do
  argument :start_year, Int
end
```

対応する GraphQL query は次のようになります:

```graphql
{
  posts(startYear: 2018) {
    id
  }
}
```

自動キャメル化を無効にするには、`argument` メソッドに `camelize: false` を渡してください。

```ruby
field :posts, [PostType], null: false do
  argument :start_year, Int, camelize: false
end
```

さらに、もし引数がすでに camelCased であれば、GraphQL schema ではそのまま camelized のままになります。ただし、その引数は resolver メソッドに渡される際に snake_case に変換されます:

```ruby
field :posts, [PostType], null: false do
  argument :startYear, Int
end

def posts(start_year:)
  # ...
end
```

見出し: 有効な引数の型

引数に使用できる型は次のとおりです:

- [`GraphQL::Schema::Scalar`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Scalar)、組み込みのスカラー（string、int、float、boolean、ID）を含む
- [`GraphQL::Schema::Enum`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Enum)
- [`GraphQL::Schema::InputObject`](https://graphql-ruby.org/api-doc/GraphQL::Schema::InputObject)、キーと値の組を入力として受け取れる
- 有効な入力型の[`GraphQL::Schema::List`](https://graphql-ruby.org/api-doc/GraphQL::Schema::List)（`[...]` を使って設定）
- 有効な入力型の[`GraphQL::Schema::NonNull`](https://graphql-ruby.org/api-doc/GraphQL::Schema::NonNull)（引数はデフォルトで non-null です。任意にするには `required: false` を使ってください）
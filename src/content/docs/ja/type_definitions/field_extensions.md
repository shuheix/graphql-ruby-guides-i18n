---
title: フィールド拡張
description: フィールドの設定と解決をプログラムで変更する
sidebar:
  order: 10
---
[`GraphQL::Schema::FieldExtension`](https://graphql-ruby.org/api-doc/GraphQL::Schema::FieldExtension) は、プログラム的にユーザー定義のfieldを変更する方法を提供します。たとえば、Relayのconnectionsはfield extensionとして実装されています（[`GraphQL::Schema::Field::ConnectionExtension`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Field::ConnectionExtension)）。

## 新しいフィールド拡張の作成

Field extensionsは[`GraphQL::Schema::FieldExtension`](https://graphql-ruby.org/api-doc/GraphQL::Schema::FieldExtension)のサブクラスとして定義します:

```ruby
class MyExtension < GraphQL::Schema::FieldExtension
end
```

## 拡張の使用方法

定義した拡張は、`extensions: [...]` オプションか `extension(...)` メソッドを使ってfieldに追加できます:

```ruby
field :name, String, null: false, extensions: [UpcaseExtension]
# or:
field :description, String, null: false do
  extension(UpcaseExtension)
end
```

以下では、拡張がfieldをどのように変更できるかを説明します。

## fieldの設定の変更

拡張がアタッチされると、`field:` と `options:` を渡されて初期化されます。次に `#apply` が呼ばれ、ここでアタッチされたfieldを拡張できます。例えば:

```ruby
class SearchableExtension < GraphQL::Schema::FieldExtension
  def apply
    # add an argument to this field:
    field.argument(:query, String, required: false, description: "A search query")
  end
end
```

このように、拡張は複数の設定オプションを必要とする振る舞いをカプセル化できます。

## デフォルトのargument設定の追加

拡張は、field自身がそのargumentを定義していない場合に適用されるデフォルトのargument設定を提供できます。設定は[`Schema::FieldExtension.default_argument`](https://graphql-ruby.org/api-doc/Schema::FieldExtension.default_argument)に渡されます。たとえば、fieldがまだ定義していない場合に`:query`引数を定義するには次のようにします:

```ruby
class SearchableExtension < GraphQL::Schema::FieldExtension
  # Any field which uses this extension and _doesn't_ define
  # its own `:query` argument will get an argument configured with this:
  default_argument(:query, String, required: false, description: "A search query")
end
```

さらに、拡張は `def after_define` を実装でき、fieldの `do .. . end` ブロックの後に呼ばれます。これは、拡張がfield定義内の何かを上書きせずにデフォルトの設定を提供する場合に有用です。（既に定義済みのfieldに対して `field.extension(...)` を呼んで拡張を追加した場合、`def after_define` は即座に呼ばれます。）

## fieldの実行の変更

拡張はfieldの解決をラップする2つのフックを持ちます。GraphQL-Rubyは遅延実行をサポートするため、これらのフックは必ずしも連続して呼ばれるとは限りません。

まず、[`GraphQL::Schema::FieldExtension#resolve`](https://graphql-ruby.org/api-doc/GraphQL::Schema::FieldExtension#resolve) が呼ばれます。`resolve` は継続するために `yield(object, arguments)` を呼ぶべきです。もし `yield` をしなければ、基底のfieldは呼ばれません。`#resolve` が返したものが実行の続行に使われます。

解決後かつ `Promise`（`graphql-batch` のような）などの遅延値の同期が終わった後に、[`GraphQL::Schema::FieldExtension#after_resolve`](https://graphql-ruby.org/api-doc/GraphQL::Schema::FieldExtension#after_resolve) が呼ばれます。そのメソッドが返すものがfieldの返り値として使われます。

これらのメソッドのパラメータについては、リンク先のAPIドキュメントを参照してください。

### 実行時の "memo"

`after_resolve` に渡される引数のうち、`memo:` は特に注意が必要です。`resolve` は第3の値を `yield` することができます。例えば:

```ruby
def resolve(object:, arguments:, **rest)
  # yield the current time as `memo`
  yield(object, arguments, Time.now.to_i)
end
```

もし第3の値が `yield` されると、それは `after_resolve` に `memo:` として渡されます。例えば:

```ruby
def after_resolve(value:, memo:, **rest)
  puts "Elapsed: #{Time.now.to_i - memo}"
  # Return the original value
  value
end
```

これにより、`resolve` フックから `after_resolve` にデータを渡すことができます。

インスタンス変数は使用できません。なぜなら、同じGraphQLクエリ内で同一のfieldが並行して複数回解決される可能性があり、その場合インスタンス変数が予測不能な形で上書きされてしまうからです。（実際、拡張はインスタンス変数の書き込みを防ぐためにfreezeされています。）

## 拡張のオプション

`extension(...)` メソッドはオプションの第2引数を取れます。例えば:

```ruby
extension(LimitExtension, limit: 20)
```

この場合、`{limit: 20}` は `#initialize` に `options:` として渡され、`options[:limit]` は `20` になります。

例えば、オプションは実行の変更に使えます:

```ruby
def after_resolve(value:, **rest)
  # Apply the limit from the options, a readable attribute on the class
  value.limit(options[:limit])
end
```

`extensions: [...]` オプションを使う場合は、ハッシュでオプションを渡せます:

```ruby
field :name, String, null: false, extensions: [LimitExtension => { limit: 20 }]
```

## `extras` の使用

拡張はfieldと同じ `extras` を持てます（参照: [Extra Field Metadata](fields/introduction#extra-field-metadata)）。クラス定義内で `extras` を呼ぶことで追加します:

```ruby
class MyExtension < GraphQL::Schema::FieldExtension
  extras [:ast_node, :errors, ...]
end
```

設定された `extras` は与えられた `arguments` に含まれますが、fieldが解決される前に削除されます。（ただし、_どの_拡張の `extras` であっても、すべての拡張の `arguments` に含まれます。）

## デフォルトで拡張を追加する

拡張を全てのfieldに適用したい場合は、あなたの[BaseField](/type_definitions/extensions.html#customizing-fields)の `def initialize` 内で行えます。例えば:

```ruby
class Types::BaseField < GraphQL::Schema::Field
  def initialize(*args, **kwargs, &block)
    super
    # Add this to all fields based on this class:
    extension(MyDefaultExtension)
  end
end
```

`def initialize` の中でキーワード引数を追加することで、条件付きで拡張を適用することもできます。例えば:

```ruby
class Types::BaseField < GraphQL::Schema::Field
  # @param custom_extension [Boolean] if false, `MyCustomExtension` won't be added
  # @example skipping `MyCustomExtension`
  #   field :no_extension, String, custom_extension: false
  def initialize(*args, custom_extension: true, **kwargs, &block)
    super(*args, **kwargs, &block)
    # Don't apply this extension if the field is configured with `custom_extension: false`:
    if custom_extension
      extension(MyCustomExtensions)
    end
  end
end
```
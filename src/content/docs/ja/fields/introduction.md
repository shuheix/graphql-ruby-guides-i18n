---
title: はじめに
description: Ruby DSL で field と resolver を実装する
sidebar:
  order: 0
---
Object fields はそのオブジェクトに関するデータを公開したり、オブジェクトを他のオブジェクトに接続したりします。`field(...)` クラスメソッドでオブジェクト type に field を追加できます。例:

```ruby
field :name, String, "The unique name of this list", null: false
```

[Objects](/type_definitions/objects) と [Interfaces](/type_definitions/interfaces) は field を持ちます。

field 定義の各要素については以下で説明します:

- [Field の名前](#fieldの名前) は GraphQL 内で field を識別します
- [Field の返り値の型](#fieldの返り値の型) はこの field が返すデータの種類を示します
- [Field のドキュメント](#fieldのドキュメント) には説明、コメント、廃止理由が含まれます
- [Field の解決](#fieldの解決) は Ruby コードを GraphQL field に結びつけます
- [Field の引数](#fieldの引数) は field がクエリ時に入力を受け取ることを可能にします
- [Field の追加メタデータ](#fieldの追加メタデータ) は GraphQL-Ruby ランタイムへの低レベルなアクセス用です
- [Field パラメータのデフォルト値の追加](#fieldパラメータのデフォルト値の追加)

## Fieldの名前

field の名前は最初の引数として、または `name:` オプションとして与えます:

```ruby
field :team_captain, ...
# or:
field ..., name: :team_captain
```

内部では、GraphQL-Ruby は field 名を **camelize** します。したがって `field :team_captain, ...` は GraphQL では `{ teamCaptain }` になります。`camelize: false` を field 定義または [デフォルトの field オプション](#fieldパラメータのデフォルト値の追加) に追加すると、この動作を無効化できます。

field の名前はまた [Field の解決](#fieldの解決) の基礎として使われます。

## Fieldの返り値の型

`field(...)` の 2 番目の引数は返り値の型です。これは以下のいずれかです:

- 組み込みの GraphQL 型 (`Integer`, `Float`, `String`, `ID`, または `Boolean`)
- アプリケーションの GraphQL 型
- 上記いずれかの _配列_（[list type](/type_definitions/lists) を表します）

[Nullability](/type_definitions/non_nulls) は `null:` キーワードで表します:

- `null: true`（デフォルト）は field が `nil` を返す可能性があることを意味します
- `null: false` は field が非 null であり、`nil` を返してはならないことを意味します。実装が `nil` を返した場合、GraphQL-Ruby はクライアントにエラーを返します。

また、リスト型は定義に `[..., null: true]` を追加することで nullable にできます。

例をいくつか示します:

```ruby
field :name, String # `String`, may return a `String` or `nil`
field :id, ID, null: false # `ID!`, always returns an `ID`, never `nil`
field :teammates, [Types::User], null: false # `[User!]!`, always returns a list containing `User`s
field :scores, [Integer, null: true] # `[Int]`, may return a list or `nil`, the list may contain a mix of `Integer`s and `nil`s
```

## Fieldのドキュメント

Field は __description__、__comment__、および __deprecated__ 情報で文書化できます。

__Descriptions__ は `field(...)` メソッドで位置引数、キーワード引数、またはブロック内で追加できます:

```ruby
# 3rd positional argument
field :name, String, "The name of this thing", null: false

# `description:` keyword
field :name, String, null: false,
  description: "The name of this thing"

# inside the block
field :name, String, null: false do
  description "The name of this thing"
end
```

__Comments__ は `field(...)` メソッドでキーワード引数、またはブロック内で追加できます:
```ruby
# `comment:` keyword
field :name, String, null: false, comment: "Rename to full name"

# inside the block
field :name, String, null: false do
  comment "Rename to full name"
end
```

次のように、コメント付きの field 名を生成します（"Rename to full name" が上）:

```graphql
type Foo {
    # Rename to full name
    name: String!
}
```

__Deprecated__ な field は `deprecation_reason:` キーワード引数を追加してマークできます:

```ruby
field :email, String,
  deprecation_reason: "Users may have multiple emails, use `User.emails` instead."
```

`deprecation_reason:` を持つ field は GraphiQL で "deprecated" と表示されます。

## Fieldの解決

一般に、field はその GraphQL 返り値の型に対応する Ruby 値を返します。たとえば、返り値の型が `String` の field は Ruby の文字列を返すべきであり、返り値の型が `[User!]!` の field は 0 個以上の `User` オブジェクトを含む Ruby 配列を返すべきです。

デフォルトでは、field は次のいずれかで値を返します:

- 基になるオブジェクトのメソッドを呼び出そうとする；または
- 基になるオブジェクトが `Hash` の場合、そのハッシュのキーを参照する。
- 上記が失敗した場合に使われるオプションの `:fallback_value` を指定できます。

メソッド名またはハッシュキーは field 名に対応するので、次の例では:

```ruby
field :top_score, Integer, null: false
```

デフォルトの挙動は `#top_score` メソッドを探すか、`Hash` のキー `:top_score`（シンボル）または `"top_score"`（文字列）を参照します。

`method:` キーワードでメソッド名を上書きしたり、`hash_key:` や `dig:` キーワードでハッシュのキーを上書きできます。例:

```ruby
# Use the `#best_score` method to resolve this field
field :top_score, Integer, null: false,
  method: :best_score

# Lookup `hash["allPlayers"]` to resolve this field
field :players, [User], null: false,
  hash_key: "allPlayers"

# Use the `#dig` method on the hash with `:nested` and `:movies` keys
field :movies, [Movie], null: false,
  dig: [:nested, :movies]
```

基になるオブジェクトに対してメソッドを呼ばずにそのまま返したい場合は、`method: :itself` を使えます:

```ruby
field :player, User, null: false,
  method: :itself
```

これは次と同等です:

```ruby
field :player, User, null: false

def player
  object
end
```

基になるオブジェクトに委譲したくない場合は、各 field に対応するメソッドを定義できます:

```ruby
# Use the custom method below to resolve this field
field :total_games_played, Integer, null: false

def total_games_played
  object.games.count
end
```

メソッド内では、いくつかのヘルパーメソッドにアクセスできます:

- `object` は基になるアプリケーションのオブジェクトです（以前は resolve 関数で `obj` と呼ばれていました）
- `context` はクエリのコンテキストです（クエリ実行時に `context:` として渡されます。以前は resolve 関数で `ctx` と呼ばれていました）

さらに、引数を定義した場合（下記参照）、それらはメソッド定義に渡されます。例:

```ruby
# Call the custom method with incoming arguments
field :current_winning_streak, Integer, null: false do
  argument :include_ties, Boolean, required: false, default_value: false
end

def current_winning_streak(include_ties:)
  # Business logic goes here
end
```

上の例が示すように、デフォルトではカスタムメソッド名は field 名と一致する必要があります。異なるカスタムメソッドを使いたい場合は、`resolver_method` オプションが利用できます:

```ruby
# Use the custom method with a non-default name below to resolve this field
field :total_games_played, Integer, null: false, resolver_method: :games_played

def games_played
  object.games.count
end
```

`resolver_method` の主なユースケースは次の 2 つです:

1. 複数の field 間での resolver の再利用
2. メソッドの競合への対処（特に `context` や `object` という名前の field がある場合）

注意: `resolver_method` は `method` や `hash_key` と組み合わせて使うことはできません。

## Fieldの引数

引数（Arguments）は、field が解決時に入力を受け取ることを可能にします。たとえば:

- `search()` field は検索に使うクエリである `term:` 引数を取るかもしれません。例: `search(term: "GraphQL")`
- `user()` field はどのユーザーを探すかを指定する `id:` 引数を取るかもしれません。例: `user(id: 1)`
- `attachments()` field はファイル種別で結果を絞る `type:` 引数を取るかもしれません。例: `attachments(type: PHOTO)`

詳細は [Arguments ガイド](/fields/arguments) を参照してください。

## Fieldの追加メタデータ

field メソッド内では、GraphQL-Ruby ランタイムの低レベルなオブジェクトにアクセスできます。これらの API は変更される可能性があるため、更新時には changelog を確認してください。

いくつかの `extras` が利用可能です:

- `ast_node`
- `graphql_name`（field の名前）
- `owner`（この field が属する type）
- `lookahead`（[Lookahead](/queries/lookahead) を参照）
- `execution_errors`。`#add(err_or_msg)` メソッドでエラーを追加します
- `argument_details`（Interpreter のみ）、引数のメタデータを持つ [`GraphQL::Execution::Interpreter::Arguments`](https://graphql-ruby.org/api-doc/GraphQL::Execution::Interpreter::Arguments) のインスタンス
- `parent`（クエリ内での以前の `object`）
- カスタム extras（下記参照）

これらを field メソッドに注入するには、まず field 定義に `extras:` オプションを追加します:

```ruby
field :my_field, String, null: false, extras: [:ast_node]
```

次にメソッドシグネチャに `ast_node:` キーワードを追加します:

```ruby
def my_field(ast_node:)
  # ...
end
```

実行時に、要求されたランタイムオブジェクトが field に渡されます。

__カスタム extras__ も可能です。field クラス上の任意のメソッドを `extras: [...]` に渡すことができ、その値がメソッドに注入されます。たとえば、`extras: [:owner]` はその field を所有する object type を注入します。カスタム field クラス上の新しいメソッドも使用できます。

## Fieldパラメータのデフォルト値の追加

field メソッドでは、field が nullable かどうかを決定する `null:` キーワード引数を渡す必要があります。別の field ではデフォルトで `true` になっている `camelize` を上書きしたいことがあるかもしれません。この挙動は、`camelize` オプションを上書きしたカスタム field を追加することで変更できます（`camelize` はデフォルトで `true` です）。

```ruby
class CustomField < GraphQL::Schema::Field
  # Add `null: false` and `camelize: false` which provide default values
  # in case the caller doesn't pass anything for those arguments.
  # **kwargs is a catch-all that will get everything else
  def initialize(*args, null: false, camelize: false, **kwargs, &block)
    # Then, call super _without_ any args, where Ruby will take
    # _all_ the args originally passed to this method and pass it to the super method.
    super
  end
end
```

Objects と Interfaces で `CustomField` を使うには、それらのクラスに `field_class` として登録する必要があります。詳細は [Customizing Fields](https://graphql-ruby.org/type_definitions/extensions#customizing-fields) を参照してください。
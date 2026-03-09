---
title: 動的な types と fields
description: 各リクエストに対して異なる schema メンバーを使う
sidebar:
  order: 8
---
各 operation ごとに異なるバージョンの GraphQL schema を使うことができます。これを行うには、`use GraphQL::Schema::Visibility` を追加し、条件付きでアクセス可能にしたい schema の部分に `visible?(context)` を実装してください。さらに、多くの schema 要素には GraphQL-Ruby がランタイムで呼び出す定義メソッドがあり、それらを再実装して有効な schema オブジェクトを返すことができます。

GraphQL-Ruby は operation の期間中、schema 要素をキャッシュしますが、以下のメソッド実装で外部サービス呼び出しを行う場合は、クライアント体験を改善しバックエンド負荷を下げるためにキャッシュ層の追加を検討してください。

ランタイムでは、名前ごと（type 名、field 名など）に表示されるオブジェクトが一つだけになるようにしてください（`.visible?(context)` が `false` を返す場合、その schema の部分は現在の operation では隠されます）。

動的な schema メンバーを使う際は、[スキーマダンプ](#スキーマダンプ) を生成するときに relevant な `context: ...` を必ず含めてください。

## 異なる fields

各 operation に対してどの field 定義を使うかをカスタマイズできます。

### `#visible?(context)` を使う

クライアントごとに異なる fields を返すには、[base field class](/type_definitions/extensions#customizing-fields) に `def visible?(context)` を実装してください。

```ruby
class Types::BaseField < GraphQL::Schema::Field
  def initialize(*args, for_staff: false, **kwargs, &block)
    super(*args, **kwargs, &block)
    @for_staff = for_staff
  end

  def visible?(context)
    super && case @for_staff
    when true
      !!context[:current_user]&.staff?
    when false
      !context[:current_user]&.staff?
    else
      true
    end
  end
end
```

その後、`for_staff: true|false` を使って field を設定できます:

```ruby
field :comments, Types::Comment.connection_type, null: false,
  description: "Comments on this blog post",
  resolver_method: :moderated_comments,
  for_staff: false

field :comments, Types::Comment.connection_type, null: false,
  description: "Comments on this blog post, including unmoderated comments",
  resolver_method: :all_comments,
  for_staff: true
```

この設定により、`post { comments { ... } }` は `context[:current_user]` が `nil` または `.staff?` でない場合は `def moderated_comments` を使用し、`context[:current_user].staff?` が `true` の場合は `def all_comments` を使用します。

### `.fields(context)` と `.get_field(name, context)` を使う

ランタイムで使う field の集合をカスタマイズするには、type クラスで `def self.fields(context)` を実装できます。これは `{ String => GraphQL::Schema::Field }` の Hash を返すべきです。

これに加えて、`.get_field(name, context)` を実装して、存在すべき場合に `name` に対応する field を返すようにしてください。例:

```ruby
class Types::User < Types::BaseObject
  def self.fields(context)
    all_fields = super
    if !context[:current_user]&.staff?
      all_fields.delete("isSpammy") # this is staff-only
    end
    all_fields
  end

  def self.get_field(name, context)
    field = super
    if field.graphql_name == "isSpammy" && !context[:current_user]&.staff?
      nil # don't show this field to non-staff
    else
      field
    end
  end
end
```

### 隠された Return Types

上で説明した field の可視性に加えて、もし field の return type が隠されている（つまり `self.visible?(context)` が `false` を返す）場合、その field も隠されます。

## 異なる arguments

fields と同様に、各 GraphQL operation に対して異なる argument 定義のセットを使えます。

### `#visible?(context)` を使う

クライアントごとに異なる arguments を提供するには、[base argument class](/type_definitions/extensions#customizing-arguments) に `def visible?(context)` を実装してください。

```ruby
class Types::BaseArgument < GraphQL::Schema::Argument
  def initialize(*args, for_staff: false, **kwargs, &block)
    super(*args, **kwargs, &block)
    @for_staff = for_staff
  end

  def visible?(context)
    super && case @for_staff
    when true
      !!context[:current_user]&.staff?
    when false
      !context[:current_user]&.staff?
    else
      true
    end
  end
end
```

その後、`for_staff: true|false` を使って argument を設定できます:

```ruby
field :user, Types::User, null: true, description: "Look up a user" do
  # Require a UUID-style ID from non-staff clients:
  argument :id, ID, required: true, for_staff: false
  # Support database primary key lookups for staff clients:
  argument :id, ID, required: false, for_staff: true
  argument :database_id, Int, required: false, for_staff: true
end

def user(id: nil, database_id: nil)
  # ...
end
```

このようにすると、staff のクライアントは `id` または `databaseId` を選べますが、非 staff のクライアントは `id` を使う必要があります。

### `def arguments(context)` と `def get_argument(name, context)` を使う

また、base field class に `def arguments(context)` を実装して `{ String => GraphQL::Schema::Argument }` の Hash を返し、`def get_argument(name, context)` を実装して [`GraphQL::Schema::Argument`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Argument) または `nil` を返す方法もあります。このアプローチを取る場合、これらのメソッドを使う type や resolver に対してカスタムの field クラスを用意するとよいでしょう。そうすれば schema の全ての fields に対してこのメソッドを再実装する必要がなくなります。

### 隠された Input Types

上で説明した argument の可視性に加えて、もし argument の input type が隠されている（つまり `self.visible?(context)` が `false` を返す）場合、その argument も隠されます。

## 異なる enum 値

### `#visible?(context)` を使う

[base enum value class](/type_definitions/extensions#customizing-enum-values) に `def visible?(context)` を実装して、特定の enum 値を特定のクライアントから隠すことができます。例:

```ruby
class BaseEnumValue < GraphQL::Schema::EnumValue
  def initialize(*args, for_staff: false, **kwargs, &block)
    super(*args, **kwargs, &block)
    @for_staff = for_staff
  end

  def visible?(context)
    super && case @for_staff
    when true
      !!context[:current_user]&.staff?
    when false
      !context[:current_user]&.staff?
    else
      true
    end
  end
end
```

この base class により、いくつかの enum 値を staff 向けまたは非 staff 向けにのみ設定できます:

```ruby
class AccountStatus < Types::BaseEnum
  value "ACTIVE"
  value "INACTIVE"
  # Use this for sensitive account statuses when the viewer is public:
  value "OTHER", for_staff: false
  # Staff-only sensitive account statuses:
  value "BANNED", for_staff: true
  value "PAYMENT_FAILED", for_staff: true
  value "PENDING_VERIFICATION", for_staff: true
end
```

### `.enum_values(context)` を使う

あるいは、enum type に `def self.enum_values(context)` を実装して [`GraphQL::Schema::EnumValue`](https://graphql-ruby.org/api-doc/GraphQL::Schema::EnumValue) の Array を返すこともできます。例えば、動的な enum 値の集合を返すには:

```ruby
class ProjectStatus < Types::BaseEnum
  def self.enum_values(context = {})
    # Fetch the values from the database
    status_names = context[:tenant].project_statuses.pluck("name")

    # Then build an Array of Enum values
    status_names.map do |name|
      # Be sure to include `owner: self`, the back-reference from the EnumValue to its parent Enum
      GraphQL::Schema::EnumValue.new(name, owner: self)
    end
  end
end
```

## 異なる types

クエリごとに異なる types を使うこともできます。いくつかの挙動は上記で定義したメソッドに依存します:

- type が return type、argument type、union のメンバー、あるいは interface の実装として使われていない場合、その type は隠されます
- interface や union にメンバーがある場合、それらは隠されます
- field の return type が隠されている場合、その field は隠されます
- argument の input type が隠されている場合、その argument は隠されます

ご想像の通り、これらの隠蔽の挙動は互いに影響し合い、同時に使うと頭を悩ませるような状況を引き起こすことがあります。

### `.visible?(context)` を使う

type クラスは `def self.visible?(context)` を実装してランタイムで自分自身を隠すことができます:

```ruby
class Types::BanReason < Types::BaseEnum
  # Hide any arguments or fields that use this enum
  # unless the current user is staff
  def self.visible?(context)
    super && !!context[:current_user]&.staff?
  end

  # ...
end
```

### 同じ type に対する異なる定義

同じ type に対して異なる実装を提供するには、次の方法があります:

- 補完的なコンテキストで `def self.visible?(context)` を実装して `true` と `false` を返す（両方が同時に `.visible? => true` にならないようにすること）。
- 上で説明したように、異なる field や argument 定義で type を schema に繋げる。

例えば、`Money` scalar を `Money` object type に移行する場合:

```ruby
# Previously, we used a simple string to describe money:
class Types::LegacyMoney < Types::BaseScalar
  # This graphql name will conflict with `Types::Money`,
  # so we have to be careful not to use them at the same time.
  # (GraphQL-Ruby will raise an error if it finds two definitions with the same name at runtime.)
  graphql_name "Money"
  describe "A string describing an amount of money."

  # Use this type definition if the current request
  # explicitly opted in to the legacy money representation:
  def self.visible?(context)
    !!context[:requests_legacy_money]
  end
end

# But we want to improve the client experience with a dedicated object type:
class Types::Money < Types::BaseObject
  field :amount, Integer, null: false
  field :currency, Types::Currency, null: false

  # Use this new definition if the client
  # didn't explicitly ask for the legacy definition:
  def self.visible?(context)
    !context[:requests_legacy_money]
  end
end
```

その後、field 定義を使って schema に定義を接続します:

```ruby
class Types::BaseField < GraphQL::Schema::Field
  def initialize(*args, legacy_money: false, **kwargs, &block)
    super(*args, **kwargs, &block)
    @legacy_money = legacy_money
  end

  def visible?(context)
    super && (@legacy_money ? !!context[:requests_legacy_money] : !context[:requests_legacy_money])
  end
end

class Types::Invoice < Types::BaseObject
  # Add one definition for each possible return type
  # (one definition will be hidden at runtime)
  field :amount, Types::LegacyMoney, null: false, legacy_money: true
  field :amount, Types::Money, null: false, legacy_money: false
end
```

input types（input objects、scalars、enums など）も argument 定義と同様に動作します。

## スキーマダンプ

ある特定のバージョンの schema をダンプするには、適切な `context: ...` を [`Schema.to_definition`](https://graphql-ruby.org/api-doc/Schema.to_definition) に渡してください。例えば:

```ruby
# Legacy money schema:
MySchema.to_definition(context: { requests_legacy_money: true })
```

または

```ruby
# Staff-only schema:
MySchema.to_definition(context: { current_user: OpenStruct.new(staff?: true) })
```

このようにすると、与えた `context` は `visible?(context)` 呼び出しやその他の関連メソッドに渡されます。
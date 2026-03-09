---
title: Changesets の定義
description: API バージョンでリリースする変更セットを作成する
sidebar:
  order: 2
enterprise: true
---
After [Changeset 統合をインストールする](/changesets/installation) in your schema, you can create Changesets which modify parts of the schema. Changesets extend `GraphQL::Enterprise::Changeset` and include a `release` string. Once a Changeset class is defined, it can be referenced with `added_in: ...` or `removed_in: ...` configurations in the schema.

__注:__ GraphQL-Enterprise 1.3.0 より前では、Changesets は `modifies ...` ブロックで設定されていました。これらのブロックは引き続きサポートされており、その API に関するドキュメントは [GitHub 上](https://github.com/rmosolgo/graphql-ruby/blob/v2.0.22/guides/changesets/definition.md) にあります。


## Changeset クラス

この Changeset は、クライアントの `context[:changeset_version]` が `2020-12-01` 以降であれば利用可能になります:

```ruby
# app/graphql/changesets/deprecate_recipe_flag.rb
class Changesets::DeprecateRecipeTags < GraphQL::Enterprise::Changeset
  release "2020-12-01"
end
```

さらに、Changesets の変更を公開するにはそれらを [リリース](/changesets/releases) する必要があります。

## `added_in:` で公開する

新しい要素は、設定に `added_in: SomeChangeset` を追加することで changeset によって公開できます。たとえば、field に新しい argument を追加するには次のようにします:

```ruby
field :search_recipes, [Types::Recipe] do
  argument :query, String
  argument :tags, [Types::RecipeTag], required: false, added_in: Changesets::AddRecipeTags
end
```

また、`added_in:` を使って実装の「置き換え」を提供することもできます。新しい定義が既存の定義と同じ名前を持つ場合、新しい定義は API の新しいバージョンで暗黙的に前の定義を置き換えます。たとえば:

```ruby
field :rating, Integer, "A 1-5 score for this recipe" # This definition will be superseded by the following one
field :rating, Float, "A 1.0-5.0 score for this recipe", added_in: Changesets::FloatingPointRatings
```

ここでは、クライアントが `Changesets::FloatingPointRatings` を含む API バージョンを要求したときに新しい `rating` 実装が使用されます。（クライアントがその changeset より前のバージョンを要求した場合は、前の実装が使用されます。）

## `removed_in:` で削除する

`removed_in:` 設定は、指定した changeset で要素を削除します。たとえば、これらの enum 値はより明確な名前のものに置き換えられます:

```ruby
class Types::RecipeTag < Types::BaseEnum
  # These are replaced by *_HEAT below:
  value :SPICY, removed_in: Changesets::ClarifyHeatTags
  value :MEDIUM, removed_in: Changesets::ClarifyHeatTags
  value :MILD, removed_in: Changesets::ClarifyHeatTags
  # These new tags are more clear:
  value :SPICY_HEAT, added_in: Changesets::ClarifyHeatTags
  value :MEDIUM_HEAT, added_in: Changesets::ClarifyHeatTags
  value :MILD_HEAT, added_in: Changesets::ClarifyHeatTags
end
```

ある要素が複数回定義されている場合、`removed_in:` 設定はその要素のすべての定義を削除します:

```ruby
class Mutations::SubmitRecipeRating < Mutations::BaseMutation
  # This is replaced in future API versions by the following argument
  argument :rating, Integer
  # This replaces the previous, but in another future version,
  # it is removed completely (and so is the previous one)
  argument :rating, Float, added_in: Changesets::FloatingPointRatings, removed_in: Changesets::RemoveRatingsCompletely
end
```

## 例

以下は changeset で行えるさまざまな変更の例です:

- [フィールド](#フィールド): フィールドの追加、変更、削除
- [引数](#引数): 引数の追加、変更、削除
- [列挙値](#列挙値): 列挙値の追加、変更、削除
- [ユニオン](#ユニオン): ユニオンへのオブジェクト型の追加または削除
- [インターフェース](#インターフェース): オブジェクト型へのインターフェース実装の追加または削除
- [型](#型): ある型定義から別の型定義への変更
- [実行時](#実行時): 現在のリクエストと changeset に基づいてランタイムで振る舞いを選択する

### フィールド

フィールドを追加または再定義するには、`field(..., added_in: ...)` を使用し、新しい実装に必要なすべての設定値を含めます（詳しくは [`GraphQL::Schema::Field#initialize`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Field#initialize) を参照してください）。ここで与えた定義は、この Changeset が適用される場合に前の定義（もしあれば）を上書きします。

```ruby
class Types::Recipe < Types::BaseObject
  # This new field is available when `context[:changeset_version]`
  # is on or after the release date of `AddRecipeTags`
  field :tags, [Types::RecipeTag], added_in: Changeset::AddRecipeTags
end
```

フィールドを削除するには、フィールドの最後の定義に `removed_in: ...` 設定を追加します:

```ruby
class Types::Recipe < Types::BaseObject
  # Even after migrating to floating point values,
  # the "rating" feature never took off,
  # so we removed it entirely eventually.
  field :rating, Integer
  field :rating, Float, added_in: Changeset::FloatingPointRatings,
    removed_in: Changeset::RemoveRatings
end
```

フィールドが削除されると、そのフィールドを要求するクエリは無効になります。ただしクライアントがそのフィールドがまだ利用可能な過去の API バージョンを要求している場合は例外です。

### 引数

引数は field、input object、resolver に属するものを追加、再定義、削除できます。新しい（または更新された）引数の定義を提供するには `added_in: ...` を使用します。たとえば:

```ruby
class Types::RecipesFilter < Types::BaseInputObject
  argument :rating, Integer
  # This new definition is available when
  # the client's `context[:changeset_version]` includes `FloatingPointRatings`
  argument :rating, Float, added_in: Changesets::FloatingPointRatings
end
```

引数を完全に削除するには、最後の定義に `removed_in: ...` を追加します。そうするとその引数のすべての実装が削除されます。たとえば:

```ruby
class Mutations::SubmitRating < Mutations::BaseMutation
  # Remove this because it's irrelevant:
  argument :phone_number, String, removed_in: Changesets::StopCollectingPersonalInformation
end
```

引数が削除されると、それらを使用するクエリはクライアントが引き続き許可される過去の API バージョンを要求していない限りスキーマによって拒否されます。

### 列挙値

Changesets を使うと、enum の値を追加、再定義、または削除できます。新しい値を追加する（または値の新しい実装を提供する）には、`value(...)` の設定に `added_in:` を含めます:

```ruby
class Types::RecipeTag < Types::BaseEnum
  # This enum will accept and return `KETO` only when the client's API version
  # includes `AddKetoDietSupport`'s release date.
  value :KETO, added_in: Changesets::AddKetoDietSupport
end
```

値は `removed_in:` で削除できます。たとえば:

```ruby
class Types::RecipeTag < Types::BaseEnum
  # Old API versions will serve this value;
  # new versions won't accept it or return it.
  value :GRAPEFRUIT_DIET, removed_in: Changesets::RemoveLegacyDiets
end
```

列挙値が削除されると、クライアントが過去の API バージョンを要求していない限り、その値は入力として受け入れられず、フィールドからの返却値としても許可されなくなります。

### ユニオン

ユニオンの possible types に型を追加または削除できます。新しいユニオンメンバーを公開するには、`possible_types` の設定に `added_in:` を含めます:

```ruby
class Types::Cookable < Types::BaseUnion
 possible_types Types::Recipe, Types::Ingredient
 # Add this to the union when clients opt in to our new feature:
 possible_types Types::Cuisine, added_in: Changeset::ReleaseCuisines
```

ユニオンからメンバーを削除するには、`possible_types` 呼び出しを `removed_in: ...` に移動します:

```ruby
# Stop including this in the union in new API versions:
possible_types Types::Chef, removed_in: Changeset::LessChefHype
```

possible type が削除されると、その型は introspection クエリやスキーマダンプでユニオン型に関連付けられなくなります。

### インターフェース

オブジェクト型のインターフェース定義に対して、追加や削除ができます。1つ以上のインターフェース実装を追加するには `implements(..., added_in:)` を使用します。これにより、この Changeset が有効なときにインターフェースとそのフィールドがオブジェクトに追加されます。たとえば:

```ruby
class Types::Recipe < Types::BaseObject
  # Add this new implementation in new API versions only:
  implements Types::RssSubject, added_in: Changesets::AddRssSupport
end
```

1つ以上のインターフェース実装を削除するには、`implements ...` 設定に `removed_in:` を追加します。たとえば:

```ruby
  implements Types::RssSubject,
    added_in: Changesets::AddRssSupport,
    # Sadly, nobody seems to want to use this,
    # so we removed it all:
    removed_in: Changesets::RemoveRssSupport
```

インターフェース実装が削除されると、そのインターフェースは introspection クエリやスキーマダンプでオブジェクトに関連付けられなくなります。また、インターフェースから継承されたフィールドはクライアントから隠されます。（オブジェクト自体がそのフィールドを定義している場合は、引き続き表示されます。）

### 型

Changesets を使用すると、古い型と同じ名前で新しい型を定義することが可能です。（クエリごとに名前あたり1つの型のみ許可されますが、異なるクエリは同じ名前に対して異なる型を使用できます。）

まず、同じ名前を持つ2つの型を定義するには、2つの異なる型定義を作成します。そのうちの1つは競合する型名を指定するために `graphql_name(...)` を使う必要があります。たとえば、enum 型を object 型に移行するには、次のように2つの型を定義します:

```ruby
# app/graphql/types/legacy_recipe_flag.rb

# In the old version of the schema, "recipe tags" were limited to defined set of values.
# This enum was renamed from `Types::RecipeTag`, then `graphql_name("RecipeTag")`
# was added for GraphQL.
class Types::LegacyRecipeTag < Types::BaseEnum
  graphql_name "RecipeTag"
  # ...
end
```

```ruby
# app/graphql/types/recipe_flag.rb

# But in the new schema, each tag is a full-fledged object with fields of its own
class Types::RecipeTag < Types::BaseObject
  field :name, String, null: false
  field :is_vegetarian, Boolean, null: false
  # ...
end
```

その後、フィールドや引数を古い型の代わりに新しい型を使うように追加または更新します。たとえば:

```diff
  class Types::Recipe < Types::BaseObject

# Change this definition to point at the newly-renamed _legacy_ type
# (It's the same type definition, but the Ruby class has a new name)
-   field :tags, [Types::RecipeTag]
+   field :tags, [Types::LegacyRecipeTag]

# And add a new field for the new type:
+   field :tags, [Types::RecipeTag], added_in: Changesets::MigrateRecipeTagToObject
  end
```

その Changeset を使うと、`Recipe.tags` は enum 型の代わりに object 型を返します。古いバージョンを要求するクライアントは引き続きそのフィールドから enum 値を受け取ります。

おそらく resolver も更新が必要です。たとえば:

```ruby
class Types::Recipe < Types::BaseObject
  # Here's the original definition which returns enum values:
  field :tags, [Types::LegacyRecipeTag], null: false
  # Here's the new definition which replaces the previous one on new API versions:
  field :tags, [Types::RecipeTag], null: false, added_in: Changesets::MigrateRecipeTagToObject

  def flags
    all_flag_objects = object.flag_objects
    if Changesets::MigrateRecipeTagToObject.active?(context)
      # Here's the new behavior, returning full objects:
      all_flag_objects
    else
      # Convert this to enum values, for legacy behavior:
      all_flag_objects.map { |f| f.name.upcase }
    end
  end
end
```

このようにして、レガシークライアントは引き続き enum 値を受け取り、新しいクライアントはオブジェクトを受け取るようにできます。

## 実行時

クエリ実行中に、Changeset が適用されているかどうかはその `.active?(context)` メソッドで確認できます。たとえば:

```ruby
class Types::Recipe
  field :flag, Types::RecipeFlag, null: true

  def flag
    # Check if this changeset applies to the current request:
    if Changesets::DeprecateRecipeFlag.active?(context)
      Stats.count(:deprecated_recipe_flag, context[:viewer])
    end
    # ...
  end
end
```

可観測性に加えて、resolver が API バージョンに応じて異なる振る舞いを選択する必要がある場合にランタイムチェックを使えます。

Changeset を定義したら、それをスキーマに追加して [リリース](/changesets/releases) してください。
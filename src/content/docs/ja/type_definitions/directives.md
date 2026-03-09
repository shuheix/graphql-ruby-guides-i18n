---
title: Directives
description: GraphQL ランタイム向けの特別な指示
sidebar:
  order: 10
---
Directives はシステム定義のキーワードで、用途は大きく分けて二つあります:

- [実行時のdirectives](#実行時のdirectives) は実行を変更します。すなわち、これらが存在する場合、GraphQL の実行時に何か異なる処理が行われます；
- [schemaのdirectives](#schemaのdirectives) はスキーマ定義に注釈を付け、スキーマや type に関する設定やメタデータを示します。

## 実行時のdirectives

実行時のdirectivesは、GraphQL の実行を変更するサーバー定義のキーワードです。すべての GraphQL 実装には少なくとも _二つ_ の directives、`@skip` と `@include` が含まれます。例えば:

```ruby
query ProfileView($renderingDetailedProfile: Boolean!){
  viewer {
    handle
    # These fields will be included only if the check passes:
    ... @include(if: $renderingDetailedProfile) {
      location
      homepageUrl
    }
  }
}
```

組み込みの2つの directive は次のように動作します:

- `@skip(if: ...)` は `if: ...` の値が truthy の場合に選択をスキップします ([`GraphQL::Schema::Directive::Skip`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Directive::Skip))
- `@include(if: ...)` は `if: ...` の値が truthy の場合に選択を含めます ([`GraphQL::Schema::Directive::Include`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Directive::Include))

### カスタムの実行時 directives

カスタムの directive は [`GraphQL::Schema::Directive`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Directive) を継承して作成します:

```ruby
# app/graphql/directives/my_directive.rb
class Directives::MyDirective < GraphQL::Schema::Directive
  description "A nice runtime customization"
  location FIELD
end
```

その後、`directive(...)` を使って schema に登録します:

```ruby
class MySchema < GraphQL::Schema
  # Attach the custom directive to the schema
  directive(Directives::MyDirective)
end
```

そしてクエリ内では `@myDirective(...)` として参照できます:

```ruby
query {
  field @myDirective {
    id
  }
}
```

[`GraphQL::Schema::Directive::Feature`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Directive::Feature) と [`GraphQL::Schema::Directive::Transform`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Directive::Transform) はライブラリ内にサンプルとして含まれています。

### 実行時 hooks

Directive クラスは、ランタイムと連携するために次のクラスメソッドを実装できます:

- `def self.include?(obj, args, ctx)`: このフックが `false` を返すと、この directive にフラグ付けされたノードは実行時にスキップされます。
- `def self.resolve(obj, args, ctx)`: フラグ付けされたノードの解決をラップします。解決処理は __block__ として渡されるので、`yield` によって解決が継続されます。

ここに挙がっていない実行時フックを探していますか？ {% open_an_issue "New directive hook: @something", "<!-- Describe how the directive would be used and then how you might implement it --> " %} で議論を始めてください！

## schemaのdirectives

schema の directives は、GraphQL のインターフェース定義言語（IDL）で使用されます。例えば、`@deprecated` は GraphQL-Ruby に組み込まれています:

```ruby
type User {
  firstName @deprecated(reason: "Use `name` instead")
  lastName @deprecated(reason: "Use `name` instead")
  name
}
```

スキーマ定義において、directives は type、field、argument に関するメタデータを表現します。

### カスタムのschema directives

カスタムの schema directive を作るには、[`GraphQL::Schema::Directive`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Directive) を継承します:

```ruby
# app/graphql/directives/permission.rb
class Directives::Permission < GraphQL::Schema::Directive
  argument :level, String
  locations FIELD_DEFINITION, OBJECT
end
```

その後、`directive(...)` を使ってスキーマの一部にアタッチします:

```ruby
class Types::JobPosting < Types::BaseObject
  directive Directives::Permission, level: "manager"
end
```

argument や field は `directives:` キーワードも受け付けます:

```ruby
field :salary, Integer, null: false,
  directives: { Directives::Permission => { level: "manager" } }
```

その後:

- 設定されたオブジェクトの `.directives` メソッドは、指定した directive のインスタンスを含む配列を返します
- IDL のダンプ（[`Schema.to_definition`](https://graphql-ruby.org/api-doc/Schema.to_definition) から得られるもの）には設定された directives が含まれます

同様に、[`Schema.from_definition`](https://graphql-ruby.org/api-doc/Schema.from_definition) は IDL 文字列から directives を解析します。

いくつかの組み込み例としては次を参照してください:

- [`GraphQL::Schema::Directive::Deprecated`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Directive::Deprecated) は `deprecation_reason` を実装しています（[`GraphQL::Schema::Member::HasDeprecationReason`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Member::HasDeprecationReason) を通じて）
- [`GraphQL::Schema::Directive::Flagged`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Directive::Flagged) は schema directives を使って [visibility](/authorization/visibility) を実装する例です

## カスタム名

デフォルトでは、directive の名前はクラス名から取られます。`graphql_name` でこれを上書きできます。例えば:

```ruby
class Directives::IsPrivate < GraphQL::Schema::Directive
  graphql_name "someOtherName"
end
```

## arguments

fields と同様に、directives も [arguments](/fields/arguments) を持てます:

```ruby
argument :if, Boolean,
  description: "Skips the selection if this condition is true"
```
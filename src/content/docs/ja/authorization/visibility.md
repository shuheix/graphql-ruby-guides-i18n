---
title: 可視性
description: プログラムで特定のユーザーから GraphQL schema の一部を非表示にします。
sidebar:
  order: 1
redirect_from:
- "/schema/limiting_visibility"
---
GraphQL-Ruby では、スキーマの一部を特定のユーザーから「非表示（hide）」にすることが可能です。これは厳密には GraphQL の仕様の一部ではありませんが、仕様の範囲内に収まる実装です。

スキーマの一部を隠したい状況の例:

- 非管理者ユーザーにスキーマの管理機能を知られたくない場合
- 新機能を段階的にリリースしたく、まずは一部のユーザーにのみ公開したい場合

## スキーマの一部を隠す

可視性制御を開始するには、プラグインを追加します:

```ruby
class MySchema < GraphQL::Schema
  # ...
  use GraphQL::Schema::Visibility # see below for options
end
```

その後、さまざまな `visible?` メソッドを再実装してスキーマの可視性をカスタマイズできます:

- Type クラスは `.visible?(context)` というクラスメソッドを持ちます
- Fields と arguments は `#visible?(context)` というインスタンスメソッドを持ちます
- Enum の値は `#visible?(context)` というインスタンスメソッドを持ちます
- Mutation クラスは `.visible?(context)` というクラスメソッドを持ちます

これらのメソッドは、`context:` として渡したハッシュに基づくクエリコンテキストで呼び出されます。メソッドが false を返すと、そのスキーマ要素はクエリ全体に対して存在しないかのように扱われます。つまり:

- introspection では、その要素は結果に含まれません
- 通常のクエリでは、その要素を参照するクエリがあれば、その要素が存在しないためバリデーションエラーになります

## 可視性プロファイル

名前付きプロファイルを使って、スキーマの可視性モードをキャッシュできます。例えば:

```ruby
use GraphQL::Schema::Visibility, profiles: {
  # mode_name => example_context_hash
  public: { public: true },
  beta: { public: true, beta: true },
  internal_admin: { internal_admin: true }
}
```

その後、`context[:visibility_profile]` を事前定義されたプロファイルのいずれかに設定してクエリを実行できます。これにより、GraphQL-Ruby は名前付きプロファイルごとのキャッシュされた型セットを作成します。`.visible?` は `profiles: ...` に渡したコンテキストハッシュでのみ呼び出されます。

渡されたプロファイルコンテキストには `visibility_profile: ...` が追加され、その後 GraphQL-Ruby によって freeze されます。

### プロファイルの事前読み込み

デフォルトでは、`Rails.env.production?` が true の場合に GraphQL-Ruby はすべての名前付き可視性プロファイルを事前読み込みします。`use ... preload: true`（または `false`）を渡してこのオプションを手動で設定できます。本番環境で事前読み込みを有効にすると、各可視性プロファイルへの最初のリクエストのレイテンシを低減できます。開発環境では事前読み込みを無効にしてアプリの起動を速くしてください。

### 動的プロファイル

名前付き可視性プロファイルを提供した場合、クエリ実行には `context[:visibility_profile]` が必須になります。キーが設定されていないクエリに対して動的な可視性を許可したい場合は、`use ..., dynamic: true` を渡すことで許可できます。これは後方互換性のサポートや、可視性の計算が事前定義するには複雑すぎる場合に便利です。

名前付きプロファイルが定義されていない場合、すべてのクエリは動的可視性を使用します。

## オブジェクトの可視性

しばらくの間秘密にしたい新機能を実装しているとします。type 内で `.visible?` を実装できます:

```ruby
class Types::SecretFeature < Types::BaseObject
  def self.visible?(context)
    # only show it to users with the secret_feature enabled
    super && context[:viewer].feature_enabled?(:secret_feature)
  end
end
```

(`super` を呼び出してデフォルトの振る舞いを継承することを常に忘れないでください。)

これにより、次の GraphQL の操作はバリデーションエラーを返します:

- `SecretFeature` を返す fields、例: `query { findSecretFeature { ... } }`
- `SecretFeature` に対するフラグメント、例: `Fragment SF on SecretFeature`

また introspection では:

- `__schema { types { ... } }` に `SecretFeature` は含まれません
- `__type(name: "SecretFeature")` は `nil` を返します
- 通常 `SecretFeature` を含む interface や union はそれを含まなくなります
- `SecretFeature` を返す fields は introspection から除外されます

## フィールドの可視性

```ruby
class Types::BaseField < GraphQL::Schema::Field
  # Pass `field ..., require_admin: true` to hide this field from non-admin users
  def initialize(*args, require_admin: false, **kwargs, &block)
    @require_admin = require_admin
    super(*args, **kwargs, &block)
  end

  def visible?(ctx)
    # if `require_admin:` was given, then require the current user to be an admin
    super && (@require_admin ? ctx[:viewer]&.admin? : true)
  end
end
```

これを機能させるには、ベースフィールドクラスを他の GraphQL types とともに [configured with other GraphQL types](/type_definitions/extensions.html#customizing-fields) しておく必要があります。

## 引数の可視性

```ruby
class Types::BaseArgument < GraphQL::Schema::Argument
  # If `require_logged_in: true` is given, then this argument will be hidden from logged-out viewers
  def initialize(*args, require_logged_in: false, **kwargs, &block)
    @require_logged_in = require_logged_in
    super(*args, **kwargs, &block)
  end

  def visible?(ctx)
    super && (@require_logged_in ? ctx[:viewer].present? : true)
  end
end
```

これを機能させるには、ベース引数クラスを他の GraphQL types とともに [configured with other GraphQL types](/type_definitions/extensions.html#customizing-arguments) しておく必要があります。

## オプトアウト

デフォルトでは、GraphQL-Ruby は常に可視性チェックを実行します。次のように schema クラスに追加することでこれを無効化できます:

```ruby
class MySchema < GraphQL::Schema
  # ...
  # Opt out of GraphQL-Ruby's visibility feature:
  use GraphQL::Schema::AlwaysVisible
end
```

大規模なスキーマでは、これによって速度が向上することがあります。

## マイグレーションに関する注意

[GraphQL::Schema::Visibility](https://graphql-ruby.org/api-doc/GraphQL::Schema::Visibility) は、GraphQL-Ruby における可視性の新しい実装です。以前の実装（[GraphQL::Schema::Warden](https://graphql-ruby.org/api-doc/GraphQL::Schema::Warden)）とはいくつかの相違点があります:

- Visibility は、ブート時にすべての型を読み込む必要がないため、Rails アプリの起動を高速化します。型はクエリで使用されるときにのみ読み込まれます。
- Visibility は、事前定義可能で再利用可能な可視性プロファイルをサポートしており、複雑な `visible?` チェックを使うクエリの高速化に寄与します。
- Visibility はいくつかのエッジケースで型を隠す挙動が若干異なります:
  - 以前は、Warden は可能な型が存在しない interface や union を隠していました。Visibility は（パフォーマンス向上のために）可能な型をチェックしないため、同様のケースでは `.visible?` が `false` を返す必要があります。さもないと、その interface や union は可視のままで可能な型を持たない状態になります。
  - オブジェクト type がスキーマに field の戻り型や union のメンバーとして接続されており、かつ interface を実装している場合に、そのオブジェクト type の「他の」スキーマへの接続が隠されていると、`orphan_types`（スキーマまたは interface による登録）されていない限り、その interface の実装者として表示されません。Warden はこのケースでオブジェクト型を検出できる「グローバル」な型マップを使用していましたが、Visibility はそのグローバルマップを持ちません。（執筆時点では、Visibility は一部のグローバル型追跡を持つようになっているので、この問題は将来的に修正される可能性があります。）
- Visibility を使用すると、いくつかの（Ruby レベルの）Schema introspection メソッドが動作しなくなります。これはそれらが参照するキャッシュが計算されていないためです（`Schema.references_to`, `Schema.union_memberships`）。これらを使用している場合は、ご連絡ください。解決方法を検討します。

### マイグレーションモード

`use GraphQL::Schema::Visibility, ... migration_errors: true` を使うとマイグレーションモードを有効にできます。このモードでは、GraphQL-Ruby は `Visibility` と `Warden` の両方で可視性チェックを行い、その結果を比較して、二つのシステムが異なる結果を返したときに詳しいエラーを発生させます。Visibility へ移行する際は、テストでこのモードを有効にして予期しない差異を見つけてください。

解決が難しいがアプリケーションの挙動に実質的な影響を与えない差異がある場合、次のフラグを `context` に設定して対処できます:

- `context[:visibility_migration_running] = true` はメインのクエリコンテキストに設定されます。
- `context[:visibility_migration_warden_running] = true` は `Warden` インスタンスに渡される複製されたコンテキストに設定されます。
- `context[:skip_migration_error] = true` を設定すると、そのクエリに対してマイグレーションエラーは発生しません。

これらのフラグを使って、テスト時に無視すべきエッジケースを条件付きで扱うことができます。
---
title: 結果のキャッシュ
description: オブジェクトとフィールドのキャッシュに関する設定オプション
sidebar:
  order: 2
enterprise: true
---
`GraphQL::Enterprise::ObjectCache` は、オブジェクトとフィールドのための複数のキャッシュ設定をサポートしています。始めるには、ベースのオブジェクトクラスとベースのフィールドクラスに extension を include し、`cacheable(...)` でデフォルトのキャッシュ挙動を設定してください:

```ruby
# app/graphql/types/base_object.rb
class Types::BaseObject < GraphQL::Schema::Object
  include GraphQL::Enterprise::ObjectCache::ObjectIntegration
  field_class Types::BaseField
  cacheable(...) # see below
  # ...
end
```

```ruby
# app/graphql/types/base_field.rb
class Types::BaseField < GraphQL::Schema::Field
  include GraphQL::Enterprise::ObjectCache::FieldIntegration
  cacheable(...) # see below
  # ...
end
```

また、ベースの interface モジュールがあなたの field クラスを利用していることを確認してください:

```ruby
# app/graphql/types/base_interface.md
module Types::BaseInterface
 field_class Types::BaseField
end
```

フィールドごとにキャッシュ設定を行うこともできます。例えば:

```ruby
field :latest_update, Types::Update, null: false, cacheable: { ttl: 60 }

field :random_number, Int, null: false, cacheable: false
```

クエリのみがキャッシュされます。`ObjectCache` は mutation と subscription を完全にスキップします。

## `cacheable(true|false)`

`cacheable(true)` は、設定された type または field が、そのキャッシュフィンガープリントが変わるまでキャッシュに格納されうることを意味します。既定では `public: false` になっており、クライアント間でキャッシュされたレスポンスを共有しません。詳細は下の [`public:`](#public) を参照してください。

`cacheable(false)` は、その type または field のキャッシュを無効にします。これを含むクエリは、既にキャッシュされている値をチェックせず、結果でキャッシュを更新もしません。

## `public:`

`cacheable(public: false)` は、type や field がキャッシュ可能であることを意味しますが、そのキャッシュキーに [`Schema.private_context_fingerprint_for(ctx)`](/object_cache/schema_setup#context-fingerprint) を含めるべきである、ということを意味します。実務上は、各クライアントが独自のキャッシュされたレスポンスを持つことになります。`cacheable(public: false)` を含むクエリは、プライベートなキャッシュキーを使用します。

`cacheable(public: true)` は、その type や field からのキャッシュ値がすべてのクライアントで共有されうることを意味します。ビューアによらず同じ公開データに対して使ってください。クエリが `public: true` の type と field のみを含む場合、キャッシュキーに `Schema.private_context_fingerprint_for(ctx)` は含まれません。こうすることで、同じクエリを要求するすべてのクライアント間でレスポンスが共有されます。

## `ttl:`

`cacheable(ttl: seconds)` は、キャッシュフィンガープリントに関係なく、指定した秒数経過後にキャッシュ値を期限切れにします。`ttl:` は次のようなケースで有効です:

- フィンガープリントを確実に生成できないオブジェクト（例: `.updated_at` タイムスタンプがない）に対して。こうした場合、保守的な `ttl` が唯一のキャッシュ有効期限の手段になることがあります。
- ルートレベルのフィールドで、一定時間後に期限切れにしたい場合。ルートレベルの `Query` にはバックエンドのオブジェクトがないことが多く、その場合キャッシュフィンガープリントも存在しません。ルートレベルのフィールドに `cacheable: { ttl: ... }` を追加することで、一定のキャッシュを持たせつつ、期限切れの保証を与えられます。
- 正しく無効化するのが難しいリストのレスポンス（下記参照）。

内部的には、`ttl:` は Redis の `EXPIRE` で実装されています。

## リストと connections のキャッシュ

リストと connection は少し追加の考慮が必要です。デフォルトでは、リスト内の各アイテムが個別にキャッシュに登録されますが、新しいアイテムが作成されるとキャッシュに知られていないため、キャッシュ済みの結果が無効化されません。これに対処するには主に 2 つのアプローチがあります。

### `has_many` リスト

キャッシュを有効に破棄するためには、リストの「親」オブジェクトに属するアイテムが作成・削除・更新されるたびに親を更新（例: Rails の `.touch`）するべきです。例えば、チームのプレイヤー一覧がある場合:

```graphql
{
  team { players { totalCount } }
}
```

レスポンスには個々の `Player` は特定されませんが、`Team` はキャッシュされます。したがって、`Player` が `Team` に追加・削除されるたびに、`Team` の `updated_at`（または他のキャッシュキー）を更新しておく必要があります。

リストがソートされうる場合は、`Player` の更新時にも `Team` を更新して、ソート済みの結果がキャッシュで無効化されるようにしてください。あるいは（または併用で）`ttl:` を使って一定期間後にキャッシュを期限切れにする方法もあります。

Rails では次のように実現できます:

```ruby
  # update the team whenever a player is saved or destroyed:
  belongs_to :team, touch: true
```

### トップレベルのリスト

"親" オブジェクトを持たない `ActiveRecord::Relation` の場合、`GraphQL::Enterprise::ObjectCache::CacheableRelation` を使って、リレーション全体の合成キャッシュエントリを作成できます。このクラスを使うにはサブクラスを作り、`def items` を実装します。例:

```ruby
class AllTeams < GraphQL::Enterprise::ObjectCache::CacheableRelation
  def items(division: nil)
    teams = Team.all
    if division
      teams = teams.where(division: division)
    end
    teams
  end
end
```

その後、resolver 内でこのクラスを使ってアイテムを取得します:

```ruby
class Query < GraphQL::Schema::Object
  field :teams, Team.connection_type do
    argument :division, Division, required: false
  end

  def teams(division: nil)
    AllTeams.items_for(self, division: division)
  end
end
```

もし [`GraphQL::Schema::Resolver`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Resolver) を使っている場合は、`.items_for` を次のように呼びます:

```ruby
def resolve(division: nil)
  # use `context[:current_object]` to get the GraphQL::Schema::Object instance whose field is being resolved
  AllTeams.items_for(context[:current_object], division: division)
end
```

最後に、`CacheableRelation` をオブジェクト識別メソッドで扱う必要があります。例えば:

```ruby
class MySchema < GraphQL::Schema
  # ...
  def self.id_from_object(object, type, ctx)
    if object.is_a?(GraphQL::Enterprise::ObjectCache::CacheableRelation)
      object.id
    else
      # The rest of your id_from_object logic here...
    end
  end

  def self.object_from_id(id, ctx)
    if (cacheable_rel = GraphQL::Enterprise::ObjectCache::CacheableRelation.find?(id))
      cacheable_rel
    else
      # The rest of your object_from_id logic here...
    end
  end
end
```

この例では、`AllTeams` はキャッシュをサポートするためにいくつかのメソッドを実装します:

- `#id` はキャッシュに適した、安定したグローバル ID を作成します
- `#to_param` はキャッシュフィンガープリントを作成します（内部で Rails の `#cache_key` を使用）
- `.find?` は ID に基づいてリストを取得します

こうしておくと、`Team` が作成された際にキャッシュ済みの結果が無効化され、新しい結果が作成されます。

あるいは（または併用で）、一定期間後にキャッシュを期限切れにするために `ttl:` を使うこともできます。

### Connections

デフォルトでは、接続関連のオブジェクト（`*Connection` や `*Edge` タイプなど）はその node type から cacheability を「継承」します。`GraphQL::Enterprise::ObjectCache::ObjectIntegration` が継承チェーンのどこかに含まれていれば、ベースクラスでこれを上書きすることもできます。

## Caching Introspection

デフォルトでは、introspection フィールドはすべてのクエリに対して public と見なされます。つまり、これらはキャッシュ可能であり、要求するクライアント間で結果が再利用されます。スキーマに ObjectCache を追加する際に（[adding the ObjectCache to your schema](/object_cache/schema_setup#add-the-cache)）、いくつかのオプションでこの挙動をカスタマイズできます:

- `cache_introspection: { public: false, ... }` はすべての introspection フィールドに対して [`public: false`](#public) を適用します。クライアントによってスキーマのメンバーを隠す場合はこれを使ってください。
- `cache_introspection: false` は introspection フィールドのキャッシュを完全に無効にします。
- `cache_introspection: { ttl: ..., ... }` は introspection フィールドのための [ttl](#ttl)（秒）を設定します。

## オブジェクトの依存関係

デフォルトでは、GraphQL Object type の `object` が、そのオブジェクト上で選択されたフィールドのキャッシュに使われます。ただし、type 定義内で `def self.cache_dependencies_for(object, context)` を実装することで、キャッシュチェックのためにどのオブジェクト（複数でも可）を使うかを指定できます。例:

```ruby
class Types::Player
  def self.cache_dependencies_for(player, context)
    # we update the team's timestamp whenever player details change,
    # so ignore the `player` for caching purposes
    player.team
  end
end
```

これを使うことで:

- 親オブジェクトに属する子のリストをキャッシュする際のパフォーマンスを改善できます
- クエリ実行時に ObjectCache に他のオブジェクトを登録できます（この場合は `cacheable_object(obj)` や `def self.object_fingerprint_for` も利用できます）

このメソッドが `Array` を返した場合、その配列内の各オブジェクトがキャッシュに登録されます。
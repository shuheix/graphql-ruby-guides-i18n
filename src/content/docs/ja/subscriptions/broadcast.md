---
title: ブロードキャスト
description: 同じ GraphQL 結果を複数のサブスクライバーに配信する
sidebar:
  order: 3
---
GraphQL の subscription 更新は、データを複数のサブスクライバーにブロードキャストすることができます。

ブロードキャストとは、subscription の更新を「一度だけ」実行し、それを「任意の数の」サブスクライバーに配信する仕組みです。これにより、サーバーが各サブスクライバーごとに GraphQL クエリを再実行する必要がなくなり、処理時間を短縮できます。

ただし、注意してください：この手法は、本来受け取るべきでないサブスクライバーに情報が漏れるリスクを伴います。

セットアップ

ブロードキャストを有効にするには、subscription のセットアップに `broadcast: true` を追加します:

```ruby
class MyAppSchema < GraphQL::Schema
  # ...
  use SomeSubscriptionImplementation,
    broadcast: true # <----
end
```

その後、ブロードキャスト可能な field は `broadcastable: true` を設定できます:

```ruby
field :name, String, null: false,
  broadcastable: true
```

subscription が送信されたとき、その subscription の全ての field が `broadcastable: true` であれば、その subscription はブロードキャストとして処理されます。

さらに、`default_broadcastable: true` を設定することもできます:

```ruby
class MyAppSchema < GraphQL::Schema
  # ...
  use SomeSubscriptionImplementation,
    broadcast: true,
    default_broadcastable: true # <----
end
```

この設定を有効にすると、field はデフォルトで broadcastable になります。設定で `broadcastable: false` が明示された field のみが、サブスクライバーごとに個別に処理されます。

どの field が broadcastable か？

GraphQL-Ruby は field が broadcastable かどうかを自動で判定できません。`broadcastable: true` または `broadcastable: false` を明示的に設定する必要があります。（subscription プラグインは `default_broadcastable: true|false` も受け付けます。）

field が broadcastable であるのは、「その field をリクエストする全てのクライアントが同じ値を見る場合」です。例えば：

- 一般的な事実：有名人の名前、物理法則、歴史的な日付
- 公開情報：オブジェクトの名前、ドキュメントの更新時刻、定型的な情報

このような field には `broadcastable: true` を付けることができます。

一方で、次のような場合は __broadcastable ではありません__：

- Viewer 固有の情報：特定の viewer に基づく field は、他の viewer にブロードキャストできません。例として `discussion { viewerCanModerate }` はモデレーターには true でも、他の viewer にブロードキャストしてはいけません。
- コンテキスト依存の情報：request のコンテキストを考慮して値が変わる field はブロードキャストすべきではありません。例として IP アドレスや HTTP ヘッダーの値は通常ブロードキャストできません。viewer のタイムゾーンを反映する field もブロードキャスト不可です。
- 制限された情報：一部の viewer がある値を見て、別の viewer が別の値を見ている場合、その field は broadcastable ではありません。こうしたデータをブロードキャストすると、非許可のクライアントに機密情報を漏らす可能性があります。（フィルタリングされたリストも含みます：フィルタが viewer ごとに異なる場合は broadcastable ではありません。）
- 副作用を伴う field：resolver の実行ごとに副作用（例：メトリクスの記録、データベースの更新、カウンタの増加）が必要な場合は、ブロードキャストの候補として適していません。なぜなら一部の実行が最適化されて省略される可能性があるためです。

これらの field には `broadcastable: false` を付けると、GraphQL-Ruby はそれらをサブスクライバーごとに個別に処理します。

もし subscription を使いたいがスキーマに非 broadcastable な field が多い場合は、別に権限を限定した subscription フィールド群を作り、それらを broadcastability に最適化することを検討してください。

内部実装

GraphQL-Ruby は、どのサブスクライバーがブロードキャストを受け取れるかを次の点を検査して判定します：

- クエリ文字列。完全に一致するクエリ文字列のみが同じブロードキャストを受け取ります。
- 変数。変数の値が完全に一致する場合のみ同じブロードキャストを受け取ります。
- `.trigger` に与えられた field と引数。これは購読時に最初に送信されたものと一致している必要があります。（subscription は常にこのように動作していました。）
- Subscription scope。subscription scope が完全に一致するクライアントのみが同じブロードキャストを受け取ります。

そのため、subscription が暗黙的にスコープされるべき場合は、[subscription_scope を設定](subscriptions/subscription_classes#scope)するよう注意してください！

（ブロードキャスト用のフィンガープリント実装については、[`GraphQL::Subscriptions::Event#fingerprint`](https://graphql-ruby.org/api-doc/GraphQL::Subscriptions::Event#fingerprint) を参照してください。）

broadcastable の確認方法

テスト目的で、GraphQL のクエリ文字列がブロードキャスト可能かどうかを [`Subscriptions#broadcastable?`](https://graphql-ruby.org/api-doc/Subscriptions#broadcastable?) を使って確認できます:

```ruby
subscription_string = "subscription { ... }"
MySchema.subscriptions.broadcastable?(subscription_string)
# => true or false
```

アプリケーションのテストでこれを使い、broadcastable な field が誤って non-broadcastable にされていないことを確認してください。

Connections と Edges

生成される `Connection` および `Edge` type を broadcastable に設定するには、それらの定義で `default_broadcastable(true)` を設定します:

```ruby
# app/types/base_connection.rb
class Types::BaseConnection < Types::BaseObject
  include GraphQL::Types::Relay::ConnectionBehaviors
  default_broadcastable(true)
end

# app/types/base_edge.rb
class Types::BaseEdge < Types::BaseObject
  include GraphQL::Types::Relay::EdgeBehaviors
  default_broadcastable(true)
end
```

（あなたの `BaseObject` では `connection_type_class(Types::BaseConnection)` と `edge_type_class(Types::BaseEdge)` も設定しているはずです。）

`PageInfo` はデフォルトで broadcastable です。
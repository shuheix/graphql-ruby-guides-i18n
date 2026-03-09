---
title: レートリミッターのデプロイ
description: リミッターをスムーズにリリースするためのヒント
sidebar:
  order: 4
enterprise: true
---
以下は GraphQL-Enterprise のレートリミッターをデプロイするためのいくつかの選択肢です:

- [ダッシュボード](#ダッシュボード) ではリミッターに関する基本的なメトリクスを表示します。
- [ソフトリミット](#ソフトリミット) は上限を超えたリクエストをダッシュボードにログし始めますが、実際にはトラフィックを停止しません。
- [サブスクリプション](#サブスクリプション) には追加の検討が必要です


## ダッシュボード

インストールすると、[GraphQL-Pro ダッシュボード](/pro/dashboard) にシンプルなメトリクスビューが表示されます:

{{ "/limiters/active_operation_limiter_dashboard.png" | link_to_img:"GraphQL Active Operation Limiter Dashboard" }}

ダッシュボードのチャートを無効にするには、設定に `use(... dashboard_charts: false)` を追加してください。

また、ダッシュボードには「soft mode」を有効/無効にするリンクがあります:

{{ "/limiters/soft_button.png" | link_to_img:"GraphQL Rate Limiter Soft Mode Button" }}

「soft mode」が有効な場合、制限されたリクエストは実際には停止されません（ただしカウントはされます）。「soft mode」が無効な場合、上限を超えたリクエストは停止されます。

詳細なメトリクスについては、各リミッターのドキュメントの "Instrumentation" セクションを参照してください。

## ソフトリミット

デフォルトでは、リミッターはクエリを実際に停止しません。代わりに「soft mode」で開始します。このモードでは:

- 制限された/されていないリクエストは[ダッシュボード](#ダッシュボード)でカウントされます
- しかし、実際にリクエストが停止されることはありません

このモードは、リミッターを本番トラフィックに適用する前にその影響を評価するためのものです。さらに、リミッターをリリースした後に本番トラフィックに悪影響が出ていることが判明した場合は、ブロッキングを止めるために「soft mode」を再度有効にすることができます。

「soft mode」を無効にして制限を開始するには、[ダッシュボード](#ダッシュボード) を使用するか、リミッターのカスタマイズメソッドのいくつかを再実装してください。

Ruby でも「soft mode」を無効にできます:

```ruby
# Turn "soft mode" off for the ActiveOperationLimiter
MySchema.enterprise_active_operation_limiter.set_soft_limit(false)
# or, for RuntimeLimiter
MySchema.enterprise_runtime_limiter.set_soft_limit(false)
```


## サブスクリプション

もし [PusherSubscriptions](/subscriptions/pusher_implementation) または [AblySubscriptions](/subscriptions/ably_implementation) を使用している場合、レートリミッターをデプロイする前に作成された subscription を考慮する必要があります。それらの subscription はすでに Redis に保存されており、その context には必須の `limiter_key:` 値が含まれていません。

これを解決するには、使用しているリミッターをカスタマイズして、この場合のデフォルト値を提供することができます。例えば:

```ruby
class CustomRuntimeLimiter < GraphQL::Enterprise::RuntimeLimiter
  def limiter_key(query)
    if query.subscription_update? && query.context[:limiter_key].nil?
      # This subscription was created before limiter_key was required,
      # so provide a value for it.
      # If `context` includes enough information to create a
      # "real" limiter key, you could also do that here.
      # In this case, we're providing a default flag:
      "legacy-subscription-update"
    else
      super
    end
  end

  def limit_for(key, query)
    if key == "legacy-subscription-update"
      nil # no limit in this case
    else
      super
    end
  end
end
```

そのようなメソッドを追加すれば、`limiter_key:` が必須になる前に作成された subscription はレート制限の対象になりません。これらのメソッドはアプリケーションに合わせて調整してください。最後に、カスタムリミッターをスキーマにアタッチすることを忘れないでください。例:

```ruby
# Use a custom subclass of GraphQL::Enterprise::RuntimeLimiter:
use CustomRuntimeLimiter, ...
```
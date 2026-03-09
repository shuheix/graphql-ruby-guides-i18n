---
title: トレーシング
description: 実行時の観測フック
sidebar:
  order: 11
redirect_from:
- "/queries/instrumentation"
---
[`GraphQL::Tracing::Trace`](https://graphql-ruby.org/api-doc/GraphQL::Tracing::Trace) はランタイム中のイベントを観測・変更するためのフックを提供します。Tracing フックはモジュール内で定義されるメソッドで、[`Schema.trace_with`](https://graphql-ruby.org/api-doc/Schema.trace_with) でミックスインします。

```ruby
module CustomTrace
  def parse(query_string:)
    # measure, log, etc
    super
  end

  # ...
end
```

クエリ実行時に trace モジュールを含めるには、スキーマに `trace_with` で追加します:

```ruby
# Run `MyCustomTrace` for all queries
class MySchema < GraphQL::Schema
  trace_with(MyCustomTrace)
end
```

メソッドとその引数の完全な一覧は、[`GraphQL::Tracing::Trace`](https://graphql-ruby.org/api-doc/GraphQL::Tracing::Trace) を参照してください。

デフォルトでは、GraphQL-Ruby はクエリ実行時に新しい trace インスタンスを生成します。既存のインスタンスを `context: { trace: ... }` として渡すことができます。また、`GraphQL.parse( ..., trace:...)` は trace インスタンスを受け付けます。

## 詳細な Tracing

クエリ実行の詳細な Tracing は [`Tracing::DetailedTrace`](https://graphql-ruby.org/api-doc/Tracing::DetailedTrace) で取得できます。これらは Google の [Perfetto Trace Viewer](https://ui.perfetto.dev) で表示できます。各 Fiber ごとの内訳が含まれ、fields と Dataloader のソース間にリンクがあります。

{{ "/queries/perfetto_example.png" | link_to_img:"GraphQL-Ruby Dataloader Perfetto Trace" }}

セットアップ方法は [`Tracing::DetailedTrace`](https://graphql-ruby.org/api-doc/Tracing::DetailedTrace) のドキュメントを参照してください。

## 外部モニタリングプラットフォーム

GraphQL-Ruby は以下の外部モニタリングシステムと統合できます:

- `ActiveSupport::Notifications`：[`Tracing::ActiveSupportNotificationsTrace`](https://graphql-ruby.org/api-doc/Tracing::ActiveSupportNotificationsTrace) を参照してください。
- [AppOptics](https://appoptics.com/) の計測は `appoptics_apm` v4.11.0+ で自動的に行われます。
- [AppSignal](https://appsignal.com/)：[`Tracing::AppsignalTrace`](https://graphql-ruby.org/api-doc/Tracing::AppsignalTrace) を参照してください。
- [Datadog](https://www.datadoghq.com)：[`Tracing::DataDogTrace`](https://graphql-ruby.org/api-doc/Tracing::DataDogTrace) を参照してください。
- [NewRelic](https://newrelic.com/)：[`Tracing::NewRelicTrace`](https://graphql-ruby.org/api-doc/Tracing::NewRelicTrace) を参照してください。
- [Prometheus](https://prometheus.io)：[`Tracing::PrometheusTrace`](https://graphql-ruby.org/api-doc/Tracing::PrometheusTrace) を参照してください。
- [Scout APM](https://www.scoutapm.com/)：[`Tracing::ScoutTrace`](https://graphql-ruby.org/api-doc/Tracing::ScoutTrace) を参照してください。
- [Sentry](https://sentry.io)：[`Tracing::SentryTrace`](https://graphql-ruby.org/api-doc/Tracing::SentryTrace) を参照してください。
- [Skylight](https://www.skylight.io)：[GraphQL probe](https://www.skylight.io/support/getting-more-from-skylight#graphql) を有効にするか、または [`Tracing::ActiveSupportNotificationsTrace`](https://graphql-ruby.org/api-doc/Tracing::ActiveSupportNotificationsTrace) を使用してください。
- Statsd：[`Tracing::StatsdTrace`](https://graphql-ruby.org/api-doc/Tracing::StatsdTrace) を参照してください。
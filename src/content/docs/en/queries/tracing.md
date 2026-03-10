---
title: Tracing
description: Observation hooks for execution
sidebar:
  order: 11
redirect_from:
- "/queries/instrumentation"
---

[`GraphQL::Tracing::Trace`](https://graphql-ruby.org/api-doc/GraphQL::Tracing::Trace) provides hooks to observe and modify events during runtime. Tracing hooks are methods, defined in modules and mixed in with [`Schema.trace_with`](https://graphql-ruby.org/api-doc/Schema.trace_with).

```ruby
module CustomTrace
  def parse(query_string:)
    # measure, log, etc
    super
  end

  # ...
end
```

To include a trace module when running queries, add it to the schema with `trace_with`:

```ruby
# Run `MyCustomTrace` for all queries
class MySchema < GraphQL::Schema
  trace_with(MyCustomTrace)
end
```

For a full list of methods and their arguments, see [`GraphQL::Tracing::Trace`](https://graphql-ruby.org/api-doc/GraphQL::Tracing::Trace).

By default, GraphQL-Ruby makes a new trace instance when it runs a query. You can pass an existing instance as `context: { trace: ... }`. Also, `GraphQL.parse( ..., trace: ...)` accepts a trace instance.

## Detailed Traces

You can capture detailed traces of query execution with [`Tracing::DetailedTrace`](https://graphql-ruby.org/api-doc/Tracing::DetailedTrace). They can be viewed in Google's [Perfetto Trace Viewer](https://ui.perfetto.dev). They include a per-Fiber breakdown with links between fields and Dataloader sources.

{{ "/queries/perfetto_example.png" | link_to_img:"GraphQL-Ruby Dataloader Perfetto Trace" }}

Learn how to set it up in the [`Tracing::DetailedTrace`](https://graphql-ruby.org/api-doc/Tracing::DetailedTrace) docs.

## External Monitoring Platforms

There integrations for GraphQL-Ruby with several other monitoring systems:

- `ActiveSupport::Notifications`: See [`Tracing::ActiveSupportNotificationsTrace`](https://graphql-ruby.org/api-doc/Tracing::ActiveSupportNotificationsTrace).
- [AppOptics](https://appoptics.com/) instrumentation is automatic in `appoptics_apm` v4.11.0+.
- [AppSignal](https://appsignal.com/): See [`Tracing::AppsignalTrace`](https://graphql-ruby.org/api-doc/Tracing::AppsignalTrace).
- [Datadog](https://www.datadoghq.com): See [`Tracing::DataDogTrace`](https://graphql-ruby.org/api-doc/Tracing::DataDogTrace).
- [NewRelic](https://newrelic.com/): See [`Tracing::NewRelicTrace`](https://graphql-ruby.org/api-doc/Tracing::NewRelicTrace).
- [Prometheus](https://prometheus.io): See [`Tracing::PrometheusTrace`](https://graphql-ruby.org/api-doc/Tracing::PrometheusTrace).
- [Scout APM](https://www.scoutapm.com/): See [`Tracing::ScoutTrace`](https://graphql-ruby.org/api-doc/Tracing::ScoutTrace).
- [Sentry](https://sentry.io): See [`Tracing::SentryTrace`](https://graphql-ruby.org/api-doc/Tracing::SentryTrace).
- [Skylight](https://www.skylight.io):  either enable the [GraphQL probe](https://www.skylight.io/support/getting-more-from-skylight#graphql) or use [`Tracing::ActiveSupportNotificationsTrace`](https://graphql-ruby.org/api-doc/Tracing::ActiveSupportNotificationsTrace).
- Statsd: See [`Tracing::StatsdTrace`](https://graphql-ruby.org/api-doc/Tracing::StatsdTrace).

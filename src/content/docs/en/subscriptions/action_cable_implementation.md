---
title: Action Cable Implementation
description: GraphQL subscriptions over ActionCable
sidebar:
  order: 4
---

[ActionCable](https://guides.rubyonrails.org/action_cable_overview.html) is a great platform for delivering GraphQL subscriptions on Rails 5+. It handles message passing (via `broadcast`) and transport (via `transmit` over a websocket).

To get started, see examples in the API docs: [`GraphQL::Subscriptions::ActionCableSubscriptions`](https://graphql-ruby.org/api-doc/GraphQL::Subscriptions::ActionCableSubscriptions). GraphQL-Ruby also includes a mock ActionCable implementation for testing: [`GraphQL::Testing::MockActionCable`](https://graphql-ruby.org/api-doc/GraphQL::Testing::MockActionCable).

See client usage for:

- [Apollo Client](/javascript_client/apollo_subscriptions)
- [Relay Modern](/javascript_client/relay_subscriptions).
- [GraphiQL](/javascript_client/graphiql_subscriptions)

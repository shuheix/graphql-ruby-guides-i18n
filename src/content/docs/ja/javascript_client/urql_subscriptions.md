---
title: urql の subscriptions
description: GraphQL-Ruby と urql を使った GraphQL subscriptions
sidebar:
  order: 4
---
GraphQL-Ruby は現在、`urql` を [ActionCable の実装](/subscriptions/action_cable_implementation) と [Pusher の実装](/subscriptions/pusher_implementation) で利用することをサポートしています。

## Pusher の設定

```js
import SubscriptionExchange from "graphql-ruby-client/subscriptions/SubscriptionExchange"
import Pusher from "pusher"
import { Client, defaultExchanges, subscriptionExchange } from 'urql'

const pusherClient = new Pusher("your-app-key", { cluster: "us2" })
const forwardToPusher = SubscriptionExchange.create({ pusher: pusherClient })

const client = new Client({
  url: '/graphql',
  exchanges: [
    ...defaultExchanges,
    subscriptionExchange({
      forwardSubscription: forwardToPusher
    }),
  ],
});
```

## ActionCable の設定

```js
import { createConsumer } from "@rails/actioncable";
import SubscriptionExchange from "graphql-ruby-client/subscriptions/SubscriptionExchange"

const actionCable = createConsumer('ws://127.0.0.1:3000/cable');
const forwardToActionCable = SubscriptionExchange.create({ consumer: actionCable })

const client = new Client({
  url: '/graphql',
  exchanges: [
    ...defaultExchanges,
    subscriptionExchange({
      forwardSubscription: forwardToActionCable
    }),
  ],
});
```

別の subscription バックエンドで `urql` を使いたいですか？ ぜひ {% open_an_issue "Using urql with ..." %} を開いてください。
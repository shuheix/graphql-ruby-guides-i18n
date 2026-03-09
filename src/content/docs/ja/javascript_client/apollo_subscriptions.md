---
title: Apollo Subscriptions
description: GraphQL-Ruby と Apollo Client を使った GraphQL subscriptions
sidebar:
  order: 2
---
GraphQL-Ruby の JavaScript クライアントには、Apollo Client 向けのいくつかのサポートが含まれています:

- Apollo Link（2.x、3.x）:
  - [概要](#apollo-link)
  - [Pusher](#apollo-link--pusher)
  - [Ably](#apollo-link--ably)
  - [ActionCable](#apollo-link--actioncable)
- Apollo 1.x:
  - [概要](#apollo-1)
  - [Pusher](#apollo-1--pusher)
  - [ActionCable](#apollo-1--actioncable)

<a id="apollo-link"></a>
## Apollo Link

Apollo Links は Apollo client 2.x および 3.x で使用されます。

<a id="apollo-link--pusher"></a>
## Apollo Link — Pusher の使用

`graphql-ruby-client` は Pusher と ApolloLink を使った subscriptions をサポートしています。

使用するには、`HttpLink` の前に `PusherLink` を追加してください。

例えば:

```js
// Load Apollo stuff
import { ApolloClient, HttpLink, ApolloLink, InMemoryCache } from "@apollo/client";
// Load PusherLink from graphql-ruby-client
import PusherLink from 'graphql-ruby-client/subscriptions/PusherLink';

// Load Pusher and create a client
import Pusher from "pusher-js"
var pusherClient = new Pusher("your-app-key", { cluster: "us2" })

// Make the HTTP link which actually sends the queries
const httpLink = new HttpLink({
  uri: '/graphql',
  credentials: 'include'
});

// Make the Pusher link which will pick up on subscriptions
const pusherLink = new PusherLink({pusher: pusherClient})

// Combine the two links to work together
const link = ApolloLink.from([pusherLink, httpLink])

// Initialize the client
const client = new ApolloClient({
  link: link,
  cache: new InMemoryCache()
});
```

このリンクはレスポンスの `X-Subscription-ID` ヘッダを確認し、存在する場合はその値を使って Pusher に対する将来の更新を subscribe します。

[圧縮ペイロード](/subscriptions/pusher_implementation#payload-compression) を使用している場合は、`decompress:` 関数も設定してください:

```javascript
// Add `pako` to the project for gunzipping
import pako from "pako"

const pusherLink = new PusherLink({
  pusher: pusherClient,
  decompress: function(compressed) {
    // Decode base64
    const data = atob(compressed)
      .split('')
      .map(x => x.charCodeAt(0));
    // Decompress
    const payloadString = pako.inflate(new Uint8Array(data), { to: 'string' });
    // Parse into an object
    return JSON.parse(payloadString);
  }
})
```

<a id="apollo-link--ably"></a>
## Apollo Link — Ably の使用

`graphql-ruby-client` は Ably と ApolloLink を使った subscriptions をサポートしています。

使用するには、`HttpLink` の前に `AblyLink` を追加してください。

例えば:

```js
// Load Apollo stuff
import { ApolloClient, HttpLink, ApolloLink, InMemoryCache } from '@apollo/client';
// Load Ably subscriptions link
import AblyLink from 'graphql-ruby-client/subscriptions/AblyLink'
// Load Ably and create a client
const Ably = require("ably")
const ablyClient = new Ably.Realtime({ key: "your-app-key" })

// Make the HTTP link which actually sends the queries
const httpLink = new HttpLink({
  uri: '/graphql',
  credentials: 'include'
});

// Make the Ably link which will pick up on subscriptions
const ablyLink = new AblyLink({ably: ablyClient})

// Combine the two links to work together
const link = ApolloLink.from([ablyLink, httpLink])

// Initialize the client
const client = new ApolloClient({
  link: link,
  cache: new InMemoryCache()
});
```

このリンクはレスポンスの `X-Subscription-ID` ヘッダを確認し、存在する場合はその値を使って Ably に対する将来の更新を subscribe します。

アプリ用の __app key__ には "Subscribe" と "Presence" 権限を持つキーを作成して使用してください。

{{ "/javascript_client/ably_key.png" | link_to_img:"Ably Subscription Key Privileges" }}

<a id="apollo-link--actioncable"></a>
## Apollo Link — ActionCable の使用

`graphql-ruby-client` は ActionCable と ApolloLink を使った subscriptions をサポートしています。

使用するには、次のように split link を構築し、以下をルーティングします:

- subscription queries を `ActionCableLink` に送る
- その他の queries を `HttpLink` に送る

例えば:

```js
import { ApolloClient, HttpLink, ApolloLink, InMemoryCache } from '@apollo/client';
import { createConsumer } from '@rails/actioncable';
import ActionCableLink from 'graphql-ruby-client/subscriptions/ActionCableLink';

const cable = createConsumer()

const httpLink = new HttpLink({
  uri: '/graphql',
  credentials: 'include'
});

const hasSubscriptionOperation = ({ query: { definitions } }) => {
  return definitions.some(
    ({ kind, operation }) => kind === 'OperationDefinition' && operation === 'subscription'
  )
}

const link = ApolloLink.split(
  hasSubscriptionOperation,
  new ActionCableLink({cable}),
  httpLink
);

const client = new ApolloClient({
  link: link,
  cache: new InMemoryCache()
});
```

Rails 5 を使用している場合、ActionCable クライアントパッケージは `@rails/actioncable` ではなく `actioncable` である点に注意してください。

<a id="apollo-1"></a>
## Apollo 1

`graphql-ruby-client` は Apollo 1 クライアントの subscriptions を [Pusher](/subscriptions/pusher_implementation) または [ActionCable](/subscriptions/action_cable_implementation) 経由でのサポートを含みます。

使用するには、`subscriptions/addGraphQLSubscriptions` を require し、ネットワークインターフェースとトランスポートクライアントを引数にして関数を呼び出してください（下の例を参照）。

サーバ側のセットアップについては、[Subscriptions ガイド](/subscriptions/overview) を参照してください。

<a id="apollo-1--pusher"></a>
### Apollo 1 — Pusher

Pusher を使うには `{pusher: pusherClient}` を渡してください:

```js
// Load Pusher and create a client
var Pusher = require("pusher-js")
var pusherClient = new Pusher(appKey, options)

// Add subscriptions to the network interface with the `pusher:` options
import addGraphQLSubscriptions from "graphql-ruby-client/subscriptions/addGraphQLSubscriptions"
addGraphQLSubscriptions(myNetworkInterface, {pusher: pusherClient})

// Optionally, add persisted query support:
var OperationStoreClient = require("./OperationStoreClient")
RailsNetworkInterface.use([OperationStoreClient.apolloMiddleware])
```

[圧縮ペイロード](/subscriptions/pusher_implementation#payload-compression) を使用している場合は、`decompress:` 関数も設定してください:

```javascript
// Add `pako` to the project for gunzipping
import pako from "pako"

addGraphQLSubscriptions(myNetworkInterface, {
  pusher: pusherClient,
  decompress: function(compressed) {
    // Decode base64
    const data = btoa(compressed)
    // Decompress
    const payloadString = pako.inflate(data, { to: 'string' })
    // Parse into an object
    return JSON.parse(payloadString);
  }
})
```

<a id="apollo-1--actioncable"></a>
### Apollo 1 — ActionCable

`{cable: cable}` を渡すことで、すべての `subscription` クエリが ActionCable にルーティングされます。

例えば:

```js
// Load ActionCable and create a consumer
var ActionCable = require('@rails/actioncable')
var cable = ActionCable.createConsumer()
window.cable = cable

// Load ApolloClient and create a network interface
var apollo = require('apollo-client')
var RailsNetworkInterface = apollo.createNetworkInterface({
 uri: '/graphql',
 opts: {
   credentials: 'include',
 },
 headers: {
   'X-CSRF-Token': $("meta[name=csrf-token]").attr("content"),
 }
});

// Add subscriptions to the network interface
import addGraphQLSubscriptions from "graphql-ruby-client/subscriptions/addGraphQLSubscriptions"
addGraphQLSubscriptions(RailsNetworkInterface, {cable: cable})

// Optionally, add persisted query support:
var OperationStoreClient = require("./OperationStoreClient")
RailsNetworkInterface.use([OperationStoreClient.apolloMiddleware])
```

---
title: Relay サブスクリプション
description: GraphQL-Ruby と Relay Modern による GraphQL subscriptions
sidebar:
  order: 3
---
`graphql-ruby-client` は Relay Modern 向けの subscriptions のサポートを3種類含みます:

- [Pusher](#pusher)
- [Ably](#ably)
- [ActionCable](#actioncable)

使用するには、`graphql-ruby-client/subscriptions/createRelaySubscriptionHandler` を require し、クライアントと必要に応じて OperationStoreClient を渡して関数を呼んでください。

__Note:__ Relay が 11 未満の場合は代わりに `import { createLegacyRelaySubscriptionHandler } from "graphql-ruby-client/subscriptions/createRelaySubscriptionHandler"` を使用してください。Relay 11 でシグネチャが変更されました。

サーバー側のセットアップについては [Subscriptions ガイド](/subscriptions/overview) を参照してください。

## Pusher の設定

[Pusher](/subscriptions/pusher_implementation) による Subscriptions には次の2つが必要です:

- [`pusher-js` ライブラリ](https://github.com/pusher/pusher-js) のクライアント
- サーバーに `subscription` operation を送るための [`fetchOperation` 関数](#fetchoperation-function)

### Pusher クライアント

Pusher 経由の Subscription 更新を受け取るには `pusher:` を渡します:

```js
// Load the helper function
import createRelaySubscriptionHandler from "graphql-ruby-client/subscriptions/createRelaySubscriptionHandler"

// Prepare a Pusher client
var Pusher = require("pusher-js")
var pusherClient = new Pusher(appKey, options)

// Create a fetchOperation, see below for more details
function fetchOperation(operation, variables, cacheConfig) {
  return fetch(...)
}

// Create a Relay Modern-compatible handler
var subscriptionHandler = createRelaySubscriptionHandler({
  pusher: pusherClient,
  fetchOperation: fetchOperation
})

// Create a Relay Modern network with the handler
var network = Network.create(fetchQuery, subscriptionHandler)
```

### 圧縮ペイロード

[圧縮ペイロード](/subscriptions/pusher_implementation#payload-compression) を使用している場合は、`decompress:` 関数も設定してください:

```javascript
// Add `pako` to the project for gunzipping
import pako from "pako"

var subscriptionHandler = createRelaySubscriptionHandler({
  pusher: pusherClient,
  fetchOperation: fetchOperation,
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

## Ably の設定

[Ably](/subscriptions/ably_implementation) による Subscriptions には次の2つが必要です:

- [`ably-js` ライブラリ](https://github.com/ably/ably-js) のクライアント
- サーバーに `subscription` operation を送るための [`fetchOperation` 関数](#fetchoperation-function)

### Ably クライアント

Ably 経由の Subscription 更新を受け取るには `ably:` を渡します:

```js
// Load the helper function
import createRelaySubscriptionHandler from "graphql-ruby-client/subscriptions/createRelaySubscriptionHandler"

// Load Ably and create a client
const Ably = require("ably")
const ablyClient = new Ably.Realtime({ key: "your-app-key" })

// create a fetchOperation, see below for more details
function fetchOperation(operation, variables, cacheConfig) {
  return fetch(...)
}

// Create a Relay Modern-compatible handler
var subscriptionHandler = createRelaySubscriptionHandler({
  ably: ablyClient,
  fetchOperation: fetchOperation
})

// Create a Relay Modern network with the handler
var network = Network.create(fetchQuery, subscriptionHandler)
```

## ActionCable の設定

この構成では、`subscription` クエリは [ActionCable](/subscriptions/action_cable_implementation) にルーティングされます。

たとえば:

```js
// Require the helper function
import createRelaySubscriptionHandler from "graphql-ruby-client/subscriptions/createRelaySubscriptionHandler")
// Optionally, load your OperationStoreClient
var OperationStoreClient = require("./OperationStoreClient")

// Create a Relay Modern-compatible handler
var subscriptionHandler = createRelaySubscriptionHandler({
  cable: createConsumer(...),
  operations: OperationStoreClient,
})

// Create a Relay Modern network with the handler
var network = Network.create(fetchQuery, subscriptionHandler)
```

## Relay の persisted query を使う場合

Relay の組み込みの [persisted query サポート](https://relay.dev/docs/guides/persisted-queries/) を使っている場合、handler に `clientName:` を渡すことで [OperationStore](/operation_store/overview.html) と連携する ID を構築できます。たとえば:

```js
var subscriptionHandler = createRelaySubscriptionHandler({
  cable: createConsumer(...),
  clientName: "web-frontend", // This should match the one you use for `sync`
})

// Create a Relay Modern network with the handler
var network = Network.create(fetchQuery, subscriptionHandler)
```

その場合、ActionCable ハンドラは Relay が提供する operation ID を使用して OperationStore とやり取りします。

## fetchOperation 関数

`fetchOperation` 関数は `fetchQuery` 関数から切り出せます。シグネチャは次のとおりです:

```js
// Returns a promise from `fetch`
function fetchOperation(operation, variables, cacheConfig) {
  return fetch(...)
}
```

- `operation`、`variables`、および `cacheConfig` は `fetchQuery` 関数の最初の3つの引数です。
- 関数は `fetch` を呼び出し、その結果（`Response` の Promise）を返すべきです。

たとえば、`Environment.js` は次のようになるかもしれません:

```js
// This function sends a GraphQL query to the server
const fetchOperation = function(operation, variables, cacheConfig) {
  const bodyValues = {
    variables,
    operationName: operation.name,
  }
  const useStoredOperations = process.env.NODE_ENV === "production"
  if (useStoredOperations) {
    // In production, use the stored operation
    bodyValues.operationId = OperationStoreClient.getOperationId(operation.name)
  } else {
    // In development, use the query text
    bodyValues.query = operation.text
  }
  return fetch('http://localhost:3000/graphql', {
    method: 'POST',
    opts: {
      credentials: 'include',
    },
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(bodyValues),
  })
}

// `fetchQuery` uses `fetchOperation`, but returns a Promise of JSON
const fetchQuery = (operation, variables, cacheConfig, uploadables) => {
  return fetchOperation(operation, variables, cacheConfig).then(response => {
    return response.json()
  })
}

// Subscriptions uses the same `fetchOperation` function for initial subscription requests
const subscriptionHandler = createRelaySubscriptionHandler({pusher: pusherClient, fetchOperation: fetchOperation})
// Combine them into a `Network`
const network = Network.create(fetchQuery, subscriptionHandler)
```

`OperationStoreClient` が `fetchOperation` 関数内で使われているため、すべての GraphQL の操作に適用されます。
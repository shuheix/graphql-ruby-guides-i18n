---
title: GraphiQL での subscriptions
description: GraphiQL IDE での GraphQL subscriptions のテスト
sidebar:
  order: 5
---
サーバを設定したら、ブラウザ内の GraphiQL IDE で subscriptions を統合できます。詳しくは [GraphiQL](https://github.com/graphql/graphiql/tree/main/packages/graphiql#readme) を参照してください。

## アプリに GraphiQL を追加する

まず、GraphiQL を表示するページを用意します。例:

```html
<!-- views/graphiqls/show.html -->
<div id="root" style="height: 100vh;"></div>
```

次に GraphiQL をインストール（例: `yarn add graphiql`）し、ページに GraphiQL をインポートしてレンダリングする JavaScript コードを追加します:

```js
import { GraphiQL } from 'graphiql'
import React from 'react'
import { createRoot } from 'react-dom/client'
import 'graphiql/graphiql.css'
import { createGraphiQLFetcher } from '@graphiql/toolkit'

const fetcher = createGraphiQLFetcher({ url: '/graphql' })
const root = createRoot(document.getElementById('root'))
root.render(<GraphiQL fetcher={fetcher}/>)
```

これでアプリ内でページを読み込むと、GraphiQL エディタが表示されるはずです。

## Ably の統合

[Ably の subscriptions](subscriptions/ably_implementation) を統合するには、`createAblyFetcher` を使用します。例:

```js
import Ably from "ably"
import createAblyFetcher from 'graphql-ruby-client/subscriptions/createAblyFetcher'

// Initialize a client
// the key must have "subscribe" and "presence" permissions
const ably = new Ably.Realtime({ key: "your.application.key" })

// Initialize a new fetcher and pass it to GraphiQL below
var fetcher = createAblyFetcher({ ably: ably, url: "/graphql" })
const root = createRoot(document.getElementById('root'))
root.render(<GraphiQL fetcher={fetcher} />)
```

内部では `window.fetch` を使ってサーバに GraphQL 操作を送信し、レスポンスの `X-Subscription-ID` ヘッダを監視します。HTTP リクエストをカスタマイズするには、`createAblyFetcher({ ... })` に `fetchOptions:` オブジェクトやカスタムの `fetch:` 関数を渡せます。

## Pusher の統合

[Pusher の subscriptions](subscriptions/pusher_implementation) を統合するには、`createPusherFetcher` を使用します。例:

```js
import Pusher from "pusher-js"
import createPusherFetcher from 'graphql-ruby-client/subscriptions/createPusherFetcher'

// Initialize a client
const pusher = new Pusher("your-app-key", { cluster: "your-cluster" })

// Initialize a new fetcher and pass it to GraphiQL below
var fetcher = createPusherFetcher({ pusher: pusher, url: "/graphql" })
const root = createRoot(document.getElementById('root'))
root.render(<GraphiQL fetcher={fetcher} />)
```

内部では `window.fetch` を使ってサーバに GraphQL 操作を送信し、レスポンスの `X-Subscription-ID` ヘッダを監視します。HTTP リクエストをカスタマイズするには、`createPusherFetcher({ ... })` に `fetchOptions:` オブジェクトやカスタムの `fetch:` 関数を渡せます。

## ActionCable の統合

[ActionCable の subscriptions](subscriptions/action_cable_implementation) を統合するには、`createActionCableFetcher` を使用します。例:

```js
import { createConsumer } from "@rails/actioncable"
import createActionCableFetcher from 'graphql-ruby-client/subscriptions/createActionCableFetcher';

// Initialize a client
const actionCable = createConsumer()

// Initialize a new fetcher and pass it to GraphiQL below
var fetcher = createActionCableFetcher({ consumer: actionCable, url: "/graphql" })
const root = createRoot(document.getElementById('root'))
root.render(<GraphiQL fetcher={fetcher} />)
```

内部ではトラフィックを分割します: `subscription { ... }` の操作は ActionCable 経由で送信され、query と mutation は `window.fetch` を使った HTTP の `POST` で送信されます。HTTP リクエストをカスタマイズするには、`createActionCableFetcher({ ... })` に `fetchOptions:` オブジェクトやカスタムの `fetch:` 関数を渡せます。
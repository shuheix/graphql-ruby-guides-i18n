---
title: OperationStore の同期
description: GraphQL-Ruby と連携した永続化クエリのための JavaScript ツール
sidebar:
  order: 1
---
JavaScript support for GraphQL projects using [graphql-pro](https://graphql.pro)'s `OperationStore` for persisted queries.

- [`sync` CLI](#sync-utility)
- [Relay &lt;2 サポート](#use-with-relay-2)
- [Relay 2+ サポート](#use-with-relay-persisted-output)
- [Apollo Client サポート](#use-with-apollo-client)
- [Apollo Link サポート](#use-with-apollo-link)
- [Apollo Codegen サポート](#use-with-apollo-codegen)
- [Apollo Android サポート](#use-with-apollo-android)
- [Apollo Persisted Queries サポート](#use-with-apollo-persisted-queries)
- [Plain JS サポート](#use-with-plain-javascript)
- [認証](#authorization)

サーバー側のセットアップについては [OperationStore ガイド](/operation_store/overview) を参照してください。

## `sync` ユーティリティ

このパッケージにはコマンドラインユーティリティ、`graphql-ruby-client sync` が含まれています:

```
$ graphql-ruby-client sync # ...
Authorizing with HMAC
Syncing 4 operations to http://myapp.com/graphql/operations...
  3 added
  1 not modified
  0 failed
Generating client module in app/javascript/graphql/OperationStoreClient.js...
✓ Done!
```

`sync` はいくつかのオプションを受け取ります:

option | description
--------|----------
`--url` | [Sync API](/operation_store/getting_started.html#add-routes) の URL
`--path` | `.graphql` / `.graphql.js` ファイルを検索するローカルディレクトリ
`--relay-persisted-output` | `relay-compiler ... --persist-output` によって生成された `.json` ファイルへのパス
`--apollo-codegen-json-output` | `apollo client:codegen ... --target json` によって生成された `.json` ファイルへのパス
`--apollo-android-operation-output` | Apollo Android によって生成された `OperationOutput.json` ファイルへのパス
`--client` | Client ID ([サーバーで作成](/operation_store/client_workflow))
`--secret` | Client Secret ([サーバーで作成](/operation_store/client_workflow))
`--outfile` | 生成されたコードの出力先
`--outfile-type` | 生成するコードの種類 (`js` または `json`)
`--header={key}:{value}` | 送信する HTTP リクエストにヘッダーを追加します（繰り返し指定可）
`--add-typename` | すべての selection set に `__typename` を追加します（Apollo Client での使用を想定）
`--verbose` | デバッグ情報を出力します
`--changeset-version` | これらのクエリを同期するときに [Changeset Version](/changesets/installation#controller-setup) を設定します（これによりランタイムでも `context[:changeset_version]` が必要になります）
`--dump-payload` | HTTP POST のペイロードを書き出すファイル。ファイル名が渡されない場合は標準出力に書き込みます。

これらおよびその他のオプションは `graphql-ruby-client sync --help` で確認できます。

## Relay &lt;2 での使用

`graphql-ruby-client` は `relay-compiler` の埋め込み `@relayHash` 値を用いてクエリを永続化できます（これは Relay の 2.0.0 より前に導入された仕組みです。Relay 2.0+ は後述します）。

クエリをサーバーに同期するには、`--path` オプションで `__generated__` ディレクトリを指定します。例えば:

```bash
# sync a Relay project
$ graphql-ruby-client sync --path=src/__generated__  --outfile=src/OperationStoreClient.js --url=...
```

生成されたコードは Relay の [Network Layer](https://relay.dev/docs/guides/network-layer/) に統合できます:

```js
// ...
// require the generated module:
const OperationStoreClient = require('./OperationStoreClient')

// ...
function fetchQuery(operation, variables, cacheConfig, uploadables) {
  const requestParams = {
    variables,
    operationName: operation.name,
  }

  if (process.env.NODE_ENV === "production")
    // In production, use the stored operation
    requestParams.operationId = OperationStoreClient.getOperationId(operation.name)
  } else {
    // In development, use the query text
    requestParams.query = operation.text,
  }

  return fetch('/graphql', {
    method: 'POST',
    headers: { /*...*/ },
    body: JSON.stringify(requestParams),
  }).then(/* ... */);
}

// ...
```

（Relay Modern のみサポートしています。Legacy Relay は静的クエリを生成できません。）

## Relay Persisted Output の使用

Relay のプロジェクトで persisted 出力を使うには、プロジェクトの [`persistConfig` オブジェクト](https://relay.dev/docs/guides/persisted-queries/) に `"file": ...` を追加します。例えば:

```json
  "relay": {
    ...
    "persistConfig": {
      "file": "./persisted-queries.json"
    }
  },
```

その後、`--relay-persisted-output` を使って Relay が生成したクエリを OperationStore サーバーにプッシュします:

```
$ graphql-ruby-client sync --relay-persisted-output=path/to/persisted-queries.json --url=...
```

この場合、`sync` は JavaScript モジュールを生成しません。`relay-compiler` が既に persisted 用にクエリを準備しているためです。代わりにネットワークレイヤーを更新して、HTTP パラメータにクライアント名と operation id を含めてください:

```js
const operationStoreClientName = "MyRelayApp";

function fetchQuery(operation, variables,) {
  return fetch('/graphql', {
    method: 'POST',
    headers: {
      'content-type': 'application/json'
    },
    body: JSON.stringify({
      // Pass the client name and the operation ID, joined by `/`
      documentId: operationStoreClientName + "/" + operation.id,
      // query: operation.text, // this is now obsolete because text is null
      variables,
    }),
  }).then(response => {
    return response.json();
  });
}
```

(Inspired by https://relay.dev/docs/guides/persisted-queries/#network-layer-changes.)

これにより、Relay アプリはクエリテキストの代わりに operation ID のみをサーバーに送信するようになります。

## Apollo Client での使用

`.graphql` ファイルを対象に `--path` オプションを指定します:

```
$ graphql-ruby-client sync --path=src/graphql/ --url=...
```

生成されたモジュールを読み込み、その `.apolloMiddleware` をネットワークインターフェースの `.use([...])` に追加します:

```js
// load the generated module
var OperationStoreClient = require("./OperationStoreClient")

// attach it as middleware in production
// (in development, send queries to the server as normal)
if (process.env.NODE_ENV === "production") {
  MyNetworkInterface.use([OperationStoreClient.apolloMiddleware])
}
```

これにより、ミドルウェアがクエリ文字列を `operationId` に置き換えます。

## Apollo Link での使用

`.graphql` ファイルを対象に `--path` オプションを指定します:

```
$ graphql-ruby-client sync --path=src/graphql/ --url=...
```

生成されたモジュールを読み込み、その `.apolloLink` を Apollo Link に組み込みます:

```js
// load the generated module
var OperationStoreClient = require("./OperationStoreClient")

// Integrate the link to another link:
const link = ApolloLink.from([
  authLink,
  OperationStoreClient.apolloLink,
  httpLink,
])

// Create a client
const client = new ApolloClient({
  link: link,
  cache: new InMemoryCache(),
});
```

__コントローラを更新してください__: Apollo Link は追加パラメータを `params[:extensions][:operationId]` のようにネストして送るため、コントローラを更新してそのパラメータを context に追加してください:

```ruby
# app/controllers/graphql_controller.rb
context = {
  # ...
  # Support Apollo Link:
  operation_id: params[:extensions][:operationId]
}
```

これで、`context[:operation_id]](https://www.apollographql.com/docs/react/api/link/persisted-queries/)` がデータベースからクエリを取得するために使われます。

## Apollo Codegen での使用

`apollo client:codegen ... --target json` を使ってアプリのクエリを含む JSON アーティファクトを生成します。生成されたアーティファクトへのパスを `graphql-ruby-client sync --apollo-codegen-json-output path/to/output.json ...` に渡してください。`sync` は Apollo によって生成された `operationId` を用いて `OperationStore` を埋めます。

その後、Apollo 形式の persisted query ID を使うには、Apollo のドキュメントに従って __Persisted Queries Link__ を導入してください。

最後に、__コントローラを更新して__ Apollo 形式の persisted query ID を operation ID として渡すようにしてください:

```ruby
# app/controllers/graphql_controller.rb
context = {
  # ...
  # Support already-synced Apollo Persisted Queries:
  operation_id: params[:extensions][:operationId]
}
```

これで、Apollo 形式の persisted query ID を使ってサーバー側の `OperationStore` から操作を取得できます。

## Apollo Android での使用

Apollo Android の [generateOperationOutput option](https://www.apollographql.com/docs/android/advanced/persisted-queries/#operationoutputjson) は `OperationOutput.json` を生成し、OperationStore と連携できます。これらのクエリを同期するには、__`--apollo-android-operation-output` オプションを使用してください__:

```sh
graphql-ruby-client sync --apollo-android-operation-output=path/to/OperationOutput.json --url=...
```

これにより、OperationStore は Apollo Android が生成したクエリ ID を使用します。

サーバー側では、クライアント名と operation ID を受け取るように __コントローラを更新__ する必要があります。例えば:

```ruby
# app/controllers/graphql_controller.rb
context = { ... }

# Check for an incoming operation ID from Apollo Client:
apollo_android_operation_id = request.headers["X-APOLLO-OPERATION-ID"]
if apollo_android_operation_id.present?
  # Check the incoming request to confirm that
  # it's your first-party client with stored operations
  client_name = # ...
  if client_name.present?
    # If we received an incoming operation ID
    # _and_ identified the client, run a persisted operation.
    context[:operation_id] = "#{client_name}/#{apollo_android_operation_id}"
  end
end
```

また、サーバーが使用する "client name" を判別できるよう、アプリ側で識別子を送信するように __アプリを更新__ する必要がある場合があります（Apollo Android はクエリハッシュを送りますが、OperationStore は `#{client_name}/#{query_hash}` 形式の ID を期待します）。

## Apollo Persisted Queries での使用

Apollo client には [Persisted Queries Link](https://www.apollographql.com/docs/react/api/link/persisted-queries/) があります。これを GraphQL-Pro の [OperationStore](/operation_store/overview) と組み合わせて使用できます。まず、[`generate-persisted-query-manifest`](https://www.apollographql.com/docs/react/api/link/persisted-queries/#1-generate-operation-manifests) でマニフェストを作成し、そのファイルのパスを `sync` に渡してください:

```sh
$ graphql-ruby-client sync --apollo-persisted-query-manifest=path/to/manifest.json ...
```

次に、Apollo Client を [persisted query マニフェストを使用するように](https://www.apollographql.com/docs/react/api/link/persisted-queries/#persisted-queries-implementation) 設定してください。

最後に、コントローラを更新して operation ID を受け取り、それを `context[:operation_id]` として渡すようにしてください:

```ruby
client_name = "..." # TODO: send the client name as a query param or header
persisted_query_hash = params[:extensions][:persistedQuery][:sha256Hash]
context = {
  # ...
  operation_id: "#{client_name}/#{persisted_query_hash}"
}
```

`operation_id` にはクライアント名が必要です。Apollo Client を使用している場合は、これを [カスタムヘッダ](https://www.apollographql.com/docs/react/networking/basic-http-networking/#customizing-request-headers) として送るか、セッションや User-Agent 等、アプリに適した方法で送信してください。

## Plain JS での使用

`OperationStoreClient.getOperationId` は operation name を受け取り、その操作のサーバー側エイリアスを返します:

```js
var OperationStoreClient = require("./OperationStoreClient")

OperationStoreClient.getOperationId("AppHomeQuery")       // => "my-frontend-app/7a8078c7555e20744cb1ff5a62e44aa92c6e0f02554868a15b8a1cbf2e776b6f"
OperationStoreClient.getOperationId("ProductDetailQuery") // => "my-frontend-app/6726a3b816e99b9971a1d25a1205ca81ecadc6eb1d5dd3a71028c4b01cc254c1"
```

GraphQL リクエストでは `operationId` を送信してください:

```js
// Lookup the operation name:
var operationId = OperationStoreClient.getOperationId(operationName)

// Include it in the params:
$.post("/graphql", {
  operationId: operationId,
  variables: queryVariables,
}, function(response) {
  // ...
})
```

## 認証

`OperationStore` は HMAC-SHA256 を用いて [authenticate requests](/operation_store/access_control) します。

認証するためにキーを `graphql-ruby-client sync` に `--secret` として渡してください:

```bash
$ export MY_SECRET_KEY= "abcdefg..."
$ graphql-ruby-client sync ... --secret=$MY_SECRET_KEY
# ...
Authenticating with HMAC
# ...
```
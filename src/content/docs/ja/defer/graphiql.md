---
title: GraphiQL での使用
description: GraphiQL IDE で @defer を使用する
sidebar:
  order: 4
pro: true
---
`@defer` と `@stream` は、ブラウザ上の IDE である [GraphiQL](https://github.com/graphql/graphiql/blob/main/packages/graphiql/README.md) で使用できます。

<img src="/defer/defer-graphiql-gif.gif"  alt="Using @defer with GraphiQL" style="max-width: 100%" />

## インクリメンタル応答

提案中の `incremental: ...` レスポンス構文を使用している場合（[提案](https://github.com/graphql/graphql-spec/pull/742)、[Ruby サポート](/defer/setup.html#example-rails-with-apollo-client)）、レスポンスの `incremental: ...` 部分を処理するためにカスタムの "fetcher" 関数が必要になります。例えば:

```js
import { meros } from "meros"; // for handling multipart responses

const customFetcher = async function* (graphqlParams, fetcherOpts) {
  // Make the initial fetch
  var result = await fetch("/graphql", {
    method: "POST",
    body: JSON.stringify(graphqlParams),
    headers: {
      'content-type': 'application/json',
    }
  }).then((r) => {
    // Use meros to turn multipart responses into streams
    return meros(r, { multiple: true })
  })

  if (!isAsyncIterable(result)) {
    // Return plain responses as promises
    return result.json()
  } else {
    // Handle multipart responses one chunk at a time
    for await (const chunk of result) {
      yield chunk.map(part => {
        // Move the incremental part of the response into top-level
        // This assumes there's only one `incremental` entry
        // which is currently true for GraphQL-Pro's @defer implementation
        var newJson = {...part.body}
        if (newJson.incremental) {
          newJson.data = newJson.incremental[0].data
          newJson.path = newJson.incremental[0].path
          delete newJson.incremental
        }
        return newJson
      });
    }
  }
}

// Helper for checking for a multipart response:
function isAsyncIterable(input) {
  return (
      typeof input === "object" &&
      input !== null &&
      (
        input[Symbol.toStringTag] === "AsyncGenerator" ||
        (Symbol.asyncIterator && Symbol.asyncIterator in input)
      )
    );
}

```

近いうちに新しい GraphiQL のバージョンがこれを標準でサポートすることを期待しています。進捗は [GitHub の issue](https://github.com/graphql/graphiql/issues/3470) をフォローしてください。
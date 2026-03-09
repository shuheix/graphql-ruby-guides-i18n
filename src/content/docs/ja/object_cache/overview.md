---
title: GraphQL ObjectCache
description: GraphQL-Ruby のサーバーサイド cache
sidebar:
  order: 0
enterprise: true
---
`GraphQL::Enterprise::ObjectCache` は GraphQL-Ruby サーバー向けのアプリケーションレベルの cache です。動作は、query 内の各オブジェクトについての [_cache fingerprint_ for each object](/object_cache/schema_setup#object-fingerprint) を保存し、それらの fingerprint が変わらない限り cache されたレスポンスを返す、というものです。cache は [TTLs](/object_cache/caching#ttl) でカスタマイズすることもできます。

## なぜ使うのか

`ObjectCache` は、query の基になるデータが変わっていない場合に cache されたレスポンスを返すことで、GraphQL のレスポンスタイムを大幅に短縮できます。

通常、GraphQL の query はデータ取得とアプリケーションロジックの呼び出しを交互に行います:


{{ "/object_cache/query-without-cache.png" | link_to_img:"GraphQL-Ruby profile, without caching" }}


しかし `ObjectCache` を使うと、先に cache を確認し、可能であれば cache されたレスポンスを返します:

{{ "/object_cache/query-with-cache.png" | link_to_img:"GraphQL-Ruby profile, with ObjectCache" }}

これによりクライアントのレイテンシが低減し、データベースやアプリケーションサーバーへの負荷も減ります。

## 仕組み

query を実行する前に、`ObjectCache` は [`GraphQL::Query#fingerprint`](https://graphql-ruby.org/api-doc/GraphQL::Query#fingerprint) と [`Schema.context_fingerprint_for(ctx)`](/object_cache/schema_setup#context-fingerprint) を使って query の fingerprint を作成します。次に、その fingerprint と一致する cached response が backend にあるかどうかを確認します。

一致が見つかった場合、`ObjectCache` はこの query で以前に訪れたオブジェクトを取得します。次に、各オブジェクトの現在の fingerprint をキャッシュ内のものと比較し、そのオブジェクトに対して `.authorized?` をチェックします。もしすべての fingerprint が一致し、すべてのオブジェクトが authorization チェックを通過すれば、cache されたレスポンスが返されます。（authorization チェックは [無効化](/object_cache/schema_setup#disabling-reauthorization) できます。）

もし cached response がないか、fingerprint が一致しない場合、incoming query は再評価されます。実行中、`ObjectCache` は遭遇した各オブジェクトの ID と fingerprint を収集します。query が完了すると、結果と新しいオブジェクトの fingerprint が cache に書き込まれます。

## セットアップ

object cache の利用を開始するには:

- [schema を準備する](/object_cache/schema_setup)
- [Redis バックエンド](/object_cache/redis) または [Memcached バックエンド](/object_cache/memcached) を設定する
- [caching のために type と field を設定する](/object_cache/caching)
- [ランタイム上の考慮事項](/object_cache/runtime_considerations) を確認する
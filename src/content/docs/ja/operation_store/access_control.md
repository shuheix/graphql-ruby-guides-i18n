---
title: アクセス制御
description: OperationStore サーバーの認証と可視性を管理します。
sidebar:
  order: 6
pro: true
---
`OperationStore`には受信する`sync`リクエストを認証する組み込みの仕組みがあります。これにより、登録されたすべてのクエリが正当な送信元から来たものであることを確認できます。

## 認証

クライアントを[追加する]({{ site.base_url }}/operation_store/client_workflow#add-a-client)と、そのクライアントに_シークレット_を関連付けます。デフォルトを使うことも独自の値を指定することもでき、クライアントのシークレットはいつでも更新できます。シークレットを更新すると、古いシークレットは無効になります。

このシークレットは、HMAC-SHA256で生成されたAuthorizationヘッダーを追加するために使用します。このヘッダーにより、サーバーは次のことを確認できます:

- リクエストが認可されたクライアントからのものであること
- リクエストが転送中に改ざんされていないこと

HMACの詳細は、[Wikipedia](https://en.wikipedia.org/wiki/Hash-based_message_authentication_code) または Ruby の [OpenSSL::HMAC](https://ruby-doc.org/stdlib-2.4.0/libdoc/openssl/rdoc/OpenSSL/HMAC.html) のドキュメントを参照してください。

Authorizationヘッダーは次の形式です:

```ruby
"GraphQL::Pro #{client_name} #{hmac}"
```

[graphql-ruby-client](/javascript_client/sync) は、指定された `--client` と `--secret` の値を使ってこのヘッダーを送信されるリクエストに追加します。
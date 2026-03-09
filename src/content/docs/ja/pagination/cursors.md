---
title: カーソル
description: 不透明なカーソルでリストを進める
sidebar:
  order: 4
---
Connectionsはページネーションされたリストを進めるために _カーソル_ を使用します。カーソルは、リスト内の特定の位置を示す不透明な文字列です。

ここで「不透明 (opaque)」とは、その文字列が値以外の意味を持たないことを意味します。_カーソル_ はデコードしたり、リバースエンジニアリングしたり、場当たり的に生成したりすべきではありません。カーソルが保証する唯一のことは、一度カーソルを取得すれば、それを使ってリストの後続または前の項目を要求できる、という点です。

カーソルは扱いが難しいこともありますが、Relay-style connectionsでは、安定的かつ高性能に実装できるため採用されています。

## カーソルのカスタマイズ

デフォルトでは、カーソルは人間のクライアントにとって不透明にするために base64 でエンコードされます。`Schema.cursor_encoder` でカスタムのエンコーダを指定できます。指定する値は `.encode(plain_text, nonce:)` と `.decode(encoded_text, nonce: false)` に応答するオブジェクトであるべきです。

たとえば、URLセーフな base-64 エンコーディングを使用するには:

```ruby
module URLSafeBase64Encoder
  def self.encode(txt, nonce: false)
    Base64.urlsafe_encode64(txt)
  end

  def self.decode(txt, nonce: false)
    Base64.urlsafe_decode64(txt)
  end
end

class MySchema < GraphQL::Schema
  # ...
  cursor_encoder(URLSafeBase64Encoder)
end
```

これで、すべての connections は URLセーフな base-64 エンコーディングを使うようになります。

connection インスタンスからは、`cursor_encoder` のメソッドに [GraphQL::Pagination::Connection](https://github.com/rmosolgo/graphql-ruby/blob/master/lib/graphql/pagination/connection.rb) の `#encode` と `#decode` 経由でアクセスできます。
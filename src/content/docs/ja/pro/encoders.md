---
title: 暗号化・バージョン管理されたカーソルとID
description: Relay識別子の不透明化と設定可能性の向上
sidebar:
  order: 6
pro: true
---
`GraphQL::Pro` には暗号化され、バージョン管理されたカーソルとIDを提供する仕組みが含まれています。これにより次のような利点があります。

- ユーザーがノードIDやconnectionのカーソルを逆解析できなくなり、攻撃ベクトルが減ります。
- カーソル戦略を段階的に切り替えられ、暗号化を追加しつつクライアントが既に持っている「古い」エンコーダを引き続きサポートできます。

`GraphQL::Pro` の暗号化エンコーダは、いくつかのセキュリティ機能を提供します。

- デフォルトで `aes-128-gcm` によるキー基盤の暗号化
- 認証
- カーソル用のノンス（IDには使用しません。そちらは無意味です）

## エンコーダの定義

エンコーダは `GraphQL::Pro::Encoder` をサブクラス化して作成できます:

```ruby
class MyEncoder < GraphQL::Pro::Encoder
  key("f411f30...")
  # optional:
  tag("81ce51c307")
end
```

- `key` はこのエンコーダ用の暗号鍵です。生成するには次のようにします: `require "securerandom"; SecureRandom.bytes(16)`
- `tag` は任意で、認証データやバージョン管理されたエンコーダの識別に使用します

## カーソルの暗号化

カーソルを暗号化するには、暗号化エンコーダを `Schema#cursor_encoder` に紐づけます:

```ruby
class MySchema GraphQL::Schema
  cursor_encoder(MyCursorEncoder)
end
```

こうすると、組み込みの connection 実装がカーソルにそのエンコーダを使います。

独自の connection を実装している場合は、エンコーダの暗号化メソッドに [`GraphQL::Pagination::Connection#encode`](https://graphql-ruby.org/api-doc/GraphQL::Pagination::Connection#encode) と [`GraphQL::Pagination::Connection#decode`](https://graphql-ruby.org/api-doc/GraphQL::Pagination::Connection#decode) 経由でアクセスできます。

## IDの暗号化

`Schema.id_from_object` と `Schema.object_from_id` でエンコーダを使うことで、IDを暗号化できます:

```ruby
class MySchema < GraphQL::Schema
  def self.id_from_object(object, type, ctx)
    id_data = "#{object.class.name}/#{object.id}"
    MyIDEncoder.encode(id_data)
  end

  def self.object_from_id(id, ctx)
    id_data = MyIDEncoder.decode(id)
    class_name, id = id_data.split("/")
    class_name.constantize.find(id)
  end
end
```

IDはノンスで暗号化されないことに注意してください。これは、誰かがIDの構成方法を「推測」できる場合、暗号鍵を特定できてしまう（[既知平文攻撃](https://en.wikipedia.org/wiki/Known-plaintext_attack) の一種）ことを意味します。このリスクを下げるために、プレーンテキストのIDを予測不可能にする（例えばソルトを付ける、内容を難読化するなど）ことを検討してください。

## バージョニング

複数のエンコーダを組み合わせて、バージョン付きのエンコーダチェーンを作れます。新しい順から古い順に `.versioned` に渡します:

```ruby
# Define some encoders ...
class NewSecureEncoder < GraphQL::Pro::Encoder
  # ...
end

class OldSecureEncoder < GraphQL::Pro::Encoder
  # ...
end

class LegacyInsecureEncoder < GraphQL::Pro::Encoder
  # ...
end

# Then order them by priority:
VersionedEncoder = GraphQL::Pro::Encoder.versioned(
  # Newest:
  NewSecureEncoder,
  OldSecureEncoder,
  # Oldest:
  LegacyInsecureEncoder
)
```

IDやカーソルを受け取る際、versioned エンコーダは順に各エンコーダを試します。新しいIDやカーソルを作成する際は、常に最初の（最新の）エンコーダを使います。これによりクライアントは新しいエンコーダを受け取りますが、サーバは古いエンコーダ（リストから削除するまで）も受け付け続けます。

`VersionedEncoder#decode_versioned` は、デコードしたデータと、それを正常にデコードしたエンコーダの二つを返します。これを使って、デコード結果の処理方法を判定できます。例えば、エンコーダによって分岐できます:

```ruby
data, encoder = VersionedEncoder.decode_versioned(id)
case encoder
when UUIDEncoder
  find_by_uuid(data)
when SQLPrimaryKeyEncoder
  find_by_pk(data)
when nil
  # `id` could not be decoded
  nil
end
```

## エンコーディング

デフォルトでは暗号化されたバイト列は base-64 として文字列化されます。`Encoder#encoder` 定義でカスタムのエンコーダを指定できます。例えば、URLセーフな base-64 を使うエンコーダを定義することもできます:

```ruby
module URLSafeEncoder
  def self.encode(str)
    Base64.urlsafe_encode64(str)
  end
  def self.decode(str)
    Base64.urlsafe_decode64(str)
  end
end
```

それをエンコーダに紐づけます:

```ruby
class MyURLSafeEncoder < GraphQL::Pro::Encoder
  encoder URLSafeEncoder
end
```

これでノードIDやカーソルが URL セーフになります。
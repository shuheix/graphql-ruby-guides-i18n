---
title: Unions
description: Unions は同じ場所に現れる可能性のある types の集合です（fields は共有しません）。
sidebar:
  order: 5
---
ユニオン type は、同じ箇所に現れる可能性のある object type の集合です。以下は [GraphQL スキーマ定義言語（SDL）](https://graphql.org/learn/schema/#union-types) で表現したユニオンの例です:

```ruby
union MediaItem = AudioClip | VideoClip | Image | TextSnippet
```

例えば、検索フィールドでこのように使うことが考えられます:

```ruby
searchMedia(term: "puppies") {
  ... on AudioClip {
    duration
  }
  ... on VideoClip {
    previewURL
    resolution
  }
  ... on Image {
    thumbnailURL
  }
  ... on TextSnippet {
    teaserText
  }
}
```

ここで、`searchMedia` field は `[MediaItem!]` を返します。各要素は `MediaItem` union の一部なので、要素ごとにどの kind のオブジェクトであるかに応じて異なるフィールドを選択したいわけです。

[Interfaces](/type_definitions/interfaces) は似た概念ですが、interface ではすべての type がいくつかの共通の fields を持つ必要があります。object types に共通の重要な fields がほとんどない場合は、unions を選ぶのが適しています。

union のメンバーは _フィールドを共有しない_ ため、選択は _常に_ 型指定のフラグメント（上の例のような `... on SomeType`）で行います。

## Union type の定義

Unions は `GraphQL::Schema::Union` を継承して定義します。まず、ベースクラスを作成します:

```ruby
class Types::BaseUnion < GraphQL::Schema::Union
end
```

次に、それを継承してスキーマ内の各ユニオンを定義します:

```ruby
class Types::CommentSubject < Types::BaseUnion
  comment "TODO comment on the union"
  description "Objects which may be commented on"
  possible_types Types::Post, Types::Image

  # Optional: if this method is defined, it will override `Schema.resolve_type`
  def self.resolve_type(object, context)
    if object.is_a?(BlogPost)
      Types::Post
    else
      Types::Image
    end
  end
end
```

`possible_types(*types)` メソッドは、この union に属する 1 個以上の types を受け取ります。

Union クラスはインスタンス化されることはありません。実行時に呼ばれるのは（定義されていれば）`.resolve_type` メソッドだけです。

`.resolve_type` に関する情報は、[Interfaces ガイド](/type_definitions/interfaces#resolve-type) を参照してください。
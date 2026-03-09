---
title: GraphQL-Ruby の API バージョニング
description: 時間をかけて、機能ごとに schema を進化させる
sidebar:
  order: 0
enterprise: true
---
Out-of-the-box, GraphQL is [設計上バージョンを持たない](https://graphql.org/learn/schema-design/)。GraphQL の拡張性により、API を継続的に拡張・改善することが可能です。_常に_ 新しい field、新しい argument、そして新しい type を追加して、新機能を実装したり既存の挙動をカスタマイズしたりできます。

ただし、ビジネス上の要件によっては別のバージョニング方式が求められることがあります。[GraphQL-Enterprise](https://graphql.pro/enterprise) の "Changesets" を使うと、schema のバージョンによってクライアントに対して _あらゆる_ 変更（破壊的変更を含む）をリリースすることができます。Changesets を使えば、既存の field を再定義したり、古い名前を使って新しい types を定義したり、enum の値を追加・削除したり──要するに何でも──しながら、既存クライアントとの互換性を維持できます。

## Changesets を使う理由

Changesets は、継続的な追加（continuous additions）を補完する進化手法です。一般的に、additive changes（新しい fields、新しい arguments、新しい types）は既存の schema に直接追加するのが最適です。しかし、schema から何かを _削除_ したり、既存部分を後方互換性のない方法で再定義する必要がある場合、Changesets が便利な手段を提供します。

例えば、Enum に値を追加する場合は、既存の schema にただ追加すればよいです:

```diff
  class Types::RecipeTag < Types::BaseEnum
    value "LOW_FAT"
    value "LOW_CARB"
+   value "VEGAN"
+   value "KETO"
+   value "GRAPEFRUIT_DIET"
  end
```

しかし、以前のクエリを _破壊する_ ような形で schema を変更したい場合は、Changeset を使って行うことができます:

```ruby
class Types::RecipeTag < Types::BaseEnum
  # Turns out this makes you sick:
  value "GRAPEFRUIT_DIET", removed_in: Changesets::RemoveLegacyDiets
end
```

この場合、この changeset より前の API バージョンを要求するクライアントのみが `GRAPEFRUIT_DIET` を使用でき、新しいバージョンを要求するクライアントはそれを入力として送信できず、レスポンスでも受け取れなくなります。

(Changesets は、加える変更（additive changes）にも対応しています。好みでそのように扱うことも可能です。)

## はじめに

Changesets の利用を始めるには、以下をご覧ください:

- [Changesets のインストール](/changesets/installation)
- [Changesets の定義](/changesets/definition)
- [Changesets のリリース](/changesets/releases)
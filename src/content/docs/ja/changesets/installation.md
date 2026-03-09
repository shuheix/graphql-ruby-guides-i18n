---
title: Changesets のインストール
description: スキーマに Changesets を追加する
sidebar:
  order: 1
enterprise: true
---
Changesets を利用するには、schema に changeset を定義するための更新と、クライアントから送られてくるバージョンヘッダを受け取るためのコントローラの更新が必要です。

## Schema の設定

[GraphQL-Enterprise](https://graphql.pro/enterprise) Changesets を使い始めるには、schema に Changesets を追加する必要があります。追加する場所はいくつかあります:

- バージョン指定の argument をサポートするには、base argument に `ArgumentIntegration` を追加してください:

    ```ruby
    # app/graphql/types/base_argument.rb
    class Types::BaseArgument < GraphQL::Schema::Argument
      include GraphQL::Enterprise::Changeset::ArgumentIntegration
    end
    ```

    また、`BaseField`、`BaseInputObject`、`BaseResolver`、`BaseMutation` に `argument_class(Types::BaseArgument)` が設定されていることを確認してください。

- バージョン指定の field をサポートするには、base field に `FieldIntegration` を追加してください:

    ```ruby
    # app/graphql/types/base_field.rb
    class Types::BaseField < GraphQL::Schema::Field
      include GraphQL::Enterprise::Changeset::FieldIntegration
      argument_class(Types::BaseArgument)
    end
    ```

    また、`BaseObject`、`BaseInterface`、`BaseMutation` に `field_class(Types::BaseField)` が設定されていることを確認してください。

- バージョン指定の enum values をサポートするには、base enum value に `EnumValueIntegration` を追加してください:

    ```ruby
    # app/graphql/types/base_enum_value.rb
    class Types::BaseEnumValue < GraphQL::Schema::EnumValue
      include GraphQL::Enterprise::Changeset::EnumValueIntegration
    end
    ```

    また、`BaseEnum` に `enum_value_class(Types::BaseEnumValue)` が設定されていることを確認してください。

- union のメンバーシップや interface の実装に対するバージョン管理をサポートするには、base type membership に `TypeMembershipIntegration` を追加してください:

    ```ruby
    # app/graphql/types/base_type_membership.rb
    class Types::BaseTypeMembership < GraphQL::Schema::TypeMembership
      include GraphQL::Enterprise::Changeset::TypeMembershipIntegration
    end
    ```

    また、`BaseUnion` と `BaseInterface` に `type_membership_class(Types::BaseTypeMembership)` が設定されていることを確認してください。TypeMemberships は GraphQL-Ruby がオブジェクト型を所属する union や実装する interface に紐付けるために使用します。カスタムの type membership クラスを使うことで、API のバージョンに応じてオブジェクトを union や interface に属させたり（あるいは属させなかったり）することができます。

これらの integration を設定すれば、[changeset を定義する](/changesets/definition) 方法を書いて、[API バージョンをリリースする](/changesets/releases) 準備が整います。

## コントローラの設定

さらに、クエリを実行する際に `context[:changeset_version]` を渡す必要があります。これを提供するために、コントローラを次のように更新してください:

```ruby
class GraphqlController < ApplicationController
  def execute
    context = {
      # ...
      changeset_version: request.headers["API-Version"], # <- Your header here. Choose something for API clients to pass.
    }
    result = MyAppSchema.execute(..., context: context)
    # ...
  end
end
```

上の例では、受信リクエストから `API-Version: ...` がパースされ、それが `context[:changeset_version]` として使われます。

`context[:changeset_version]` が `nil` の場合、そのリクエストには Changesets は適用されません。

Changesets をインストールしたので、次に [changesets を定義する](/changesets/definition) 方法を読み進めてください。
---
title: Pundit の統合
description: GraphQL を Pundit のポリシーに接続する
sidebar:
  order: 4
pro: true
---
[GraphQL::Pro](https://graphql.pro) には [Pundit](https://github.com/varvet/pundit) ポリシーで GraphQL の認可を行うための統合が含まれています。

__なぜわざわざ？__ 認可コードを直接 GraphQL の type に書くこともできますが、別の認可レイヤーを用意するといくつか利点があります:

- 認可コードが GraphQL に埋め込まれていないため、GraphQL 以外（あるいはレガシー）なアプリ部分でも同じロジックを使えます。
- 認可ロジックを単独でテストできるので、エンドツーエンドの GraphQL テストで扱うケースを減らせます。

## はじめに

__注意__: 最新の gem が必要です。`Gemfile` に次を含めてください:

```ruby
# For PunditIntegration:
gem "graphql-pro", ">=1.7.9"
# For list scoping:
gem "graphql", ">=1.8.7"
```

その後、`bundle install` を実行します。

クエリを実行する際は、context に `:current_user` を含めてください:

```ruby
context = {
  current_user: current_user,
  # ...
}
MySchema.execute(..., context: context)
```

### Rails ジェネレーター

スキーマファイルが `rails generate graphql:install` と同じ構成に従っている場合、Rails ジェネレーターで Pundit 統合をインストールできます:

```bash
$ rails generate graphql:pundit:install
```

これにより下記で説明する必要な `include ...` が挿入されます。あるいは、以下のドキュメントを参照して `PunditIntegration` のモジュールを手動で mix in してください。

## オブジェクトの認可

ある type のオブジェクトを閲覧するために満たすべき Pundit の role を指定できます。まず、ベースの object クラスに `ObjectIntegration` を include してください:

```ruby
# app/graphql/types/base_object.rb
class Types::BaseObject < GraphQL::Schema::Object
  # Add the Pundit integration:
  include GraphQL::Pro::PunditIntegration::ObjectIntegration
  # By default, require staff:
  pundit_role :staff
  # Or, to require no permissions by default:
  # pundit_role nil
end
```

これで、GraphQL オブジェクトを読み取ろうとする全てのユーザーは、そのオブジェクトの policy に対する `#staff?` チェックを通過する必要があります。

その後、各子クラスは親の設定を上書きできます。例えば、`Query` ルートを全員に許可するには次のようにします:

```ruby
class Types::Query < Types::BaseObject
  # Allow anyone to see the query root
  pundit_role nil
end
```

#### ポリシーとメソッド

GraphQL が返す各オブジェクトについて、統合はそれをポリシーにマッチさせ、メソッドを呼び出します。

ポリシーは [`Pundit.policy!`](https://www.rubydoc.info/gems/pundit/Pundit%2Epolicy!) を使って見つけます。これはオブジェクトのクラス名を使ってポリシーを参照します。（カスタマイズ可能です。下記参照）

その後、GraphQL はポリシー上のメソッドを呼び出して、そのオブジェクトが許可されているかどうかを判定します。これはオブジェクトクラスで次のように設定します:

```ruby
class Types::Employee < Types::BaseObject
  # Only show employee objects to their bosses,
  # or when that employee is the current viewer
  pundit_role :employer_or_self
  # ...
end
```

この設定では、対応する Pundit ポリシーの `#employer_or_self?` が呼び出されます。

#### カスタムポリシークラス

デフォルトでは、統合は `Pundit.policy!(current_user, object)` を使ってポリシーを見つけます。`pundit_policy_class(...)` を使ってポリシークラスを指定できます:

```ruby
class Types::Employee < Types::BaseObject
  pundit_policy_class(Policies::CustomEmployeePolicy)
  # Or, you could use a string:
  # pundit_policy_class("Policies::CustomEmployeePolicy")
end
```

より柔軟なポリシー検索については、下の [カスタムポリシーの検索](#custom-policy-lookup) を参照してください。

#### ポリシーをバイパスする

統合は、`pundit_role` が設定されている全てのオブジェクトに対応するポリシークラスがあることを要求します。オブジェクトが認可をスキップできるようにするには、role に `nil` を渡します:

```ruby
class Types::PublicProfile < Types::BaseObject
  # Anyone can see this
  pundit_role nil
end
```

#### 非認可オブジェクトの処理

任意の Policy メソッドが `false` を返した場合、非認可のオブジェクトは [`Schema.unauthorized_object`](https://graphql-ruby.org/api-doc/Schema.unauthorized_object) に渡されます。詳細は [未承認オブジェクトの処理](/authorization/authorization#handling-unauthorized-objects) を参照してください。

## スコープ

Pundit 統合は GraphQL-Ruby の [list scoping](/authorization/scoping) 機能に [Pundit スコープ](https://github.com/varvet/pundit#scopes) を追加します。あらゆるリストや connection はスコープされます。スコープが見つからない場合、フィルタされていないデータが漏れるリスクを避けるためにクエリはクラッシュします。

interface や union type のリストをスコープするには、ベースの union クラスとベースの interface モジュールに統合を include してください:

```ruby
class BaseUnion < GraphQL::Schema::Union
  include GraphQL::Pro::PunditIntegration::UnionIntegration
end

module BaseInterface
  include GraphQL::Schema::Interface
  include GraphQL::Pro::PunditIntegration::InterfaceIntegration
end
```

#### スコープのバイパス

field からスコープされていない relation を返すことを許可するには、`scope: false` でスコーピングを無効にします。例えば:

```ruby
# Allow anyone to browse the job postings
field :job_postings, [Types::JobPosting], null: false,
  scope: false
```

## field の認可

フィールド単位で特定のチェックを要求することもできます。まず、ベースの field クラスに統合を include します:

```ruby
# app/graphql/types/base_field.rb
class Types::BaseField < GraphQL::Schema::Field
  # Add the Pundit integration:
  include GraphQL::Pro::PunditIntegration::FieldIntegration
  # By default, don't require a role at field-level:
  pundit_role nil
end
```

まだ行っていない場合は、ベース field クラスをベース object やベース interface に接続してください:

```ruby
# app/graphql/types/base_object.rb
class Types::BaseObject < GraphQL::Schema::Object
  field_class Types::BaseField
end
# app/graphql/types/base_interface.rb
module Types::BaseInterface
  # ...
  field_class Types::BaseField
end
# app/graphql/mutations/base_mutation.rb
class Mutations::BaseMutation < GraphQL::Schema::RelayClassicMutation
  field_class Types::BaseField
end
```

その上で、field に `pundit_role:` オプションを追加できます:

```ruby
class Types::JobPosting < Types::BaseObject
  # Allow signed-in users to browse listings
  pundit_role :signed_in

  # But, only allow `JobPostingPolicy#staff?` users to see
  # who has applied
  field :applicants, [Types::User],
    pundit_role: :staff
end
```

これは親オブジェクトのポリシー（例えば `JobPostingPolicy`）上の名前付き role（例: `#staff?`）を呼び出します。

#### カスタムポリシークラス

field ごとにポリシークラスを上書きするには `pundit_policy_class:` を使います。例えば:

```ruby
class Types::JobPosting < Types::BaseObject
  # Only allow `ApplicantsPolicy#staff?` users to see
  # who has applied
  field :applicants, [Types::User],
    pundit_role: :staff,
    pundit_policy_class: ApplicantsPolicy
    # Or with a string:
    # pundit_policy_class: "ApplicantsPolicy"
end
```

これにより、親オブジェクト（`Job`）を渡して `ApplicantsPolicy` が初期化され、その上で `#staff?` が呼ばれます。

より柔軟なポリシー検索については、下の [カスタムポリシーの検索](#custom-policy-lookup) を参照してください。

## 引数の認可

field レベルのチェックと同様に、特定の引数を「使用する」ために権限を要求できます。これを行うには、ベースの argument クラスに統合を追加します:

```ruby
class Types::BaseArgument < GraphQL::Schema::Argument
  # Include the integration and default to no permissions required
  include GraphQL::Pro::PunditIntegration::ArgumentIntegration
  pundit_role nil
end
```

その後、ベース argument がベース field とベース input object に接続されていることを確認してください:

```ruby
class Types::BaseField < GraphQL::Schema::Field
  argument_class Types::BaseArgument
  # PS: see "Authorizing Fields" to make sure your base field is hooked up to objects, interfaces and mutations
end

class Types::BaseInputObject < GraphQL::Schema::InputObject
  argument_class Types::BaseArgument
end

class Mutations::BaseMutation < GraphQL::Schema::RelayClassicMutation
  argument_class Types::BaseArgument
end
```

これで、引数は `pundit_role:` オプションを受け付けます。例えば:

```ruby
class Types::Company < Types::BaseObject
  field :employees, Types::Employee.connection_type do
    # Only admins can filter employees by email:
    argument :email, String, required: false, pundit_role: :admin
  end
end
```

上記の例では、その role は親オブジェクトのポリシー上で呼ばれます。つまり `CompanyPolicy#admin?` が呼ばれます。

## mutation の認可

Pundit 統合で GraphQL の mutation を認可する方法はいくつかあります:

- [mutation レベルの役割](#mutation-level-roles) を追加する
- [ID でロードされたオブジェクト](#authorizing-loaded-objects) に対してチェックを実行する

また、[未承認オブジェクトの処理](#unauthorized-mutations) を設定できます。

#### セットアップ

ベース mutation に `MutationIntegration` を追加してください。例:

```ruby
class Mutations::BaseMutation < GraphQL::Schema::RelayClassicMutation
  include GraphQL::Pro::PunditIntegration::MutationIntegration

  # Also, to use argument-level authorization:
  argument_class Types::BaseArgument
end
```

また、デフォルトの role を設定できる `BaseMutationPayload` を用意するのが良いでしょう:

```ruby
class Types::BaseMutationPayload < Types::BaseObject
  # If `BaseObject` requires some permissions, override that for mutation results.
  # Assume that anyone who can run a mutation can read their generated result types.
  pundit_role nil
end
```

そしてそれをベース mutation に接続します:

```ruby
class Mutations::BaseMutation < GraphQL::Schema::RelayClassicMutation
  object_class Types::BaseMutationPayload
  field_class Types::BaseField
end
```

#### Mutation レベルの役割

各 mutation はクラスレベルの `pundit_role` を持てます。これはオブジェクトのロードや resolve の前にチェックされます。例えば:

```ruby
class Mutations::PromoteEmployee < Mutations::BaseMutation
  pundit_role :admin
end
```

上の例では、`PromoteEmployeePolicy#admin?` が mutation 実行前にチェックされます。

#### カスタムポリシークラス

デフォルトでは、Pundit は mutation のクラス名を使ってポリシーを検索します。mutation 上で `pundit_policy_class` を定義して上書きできます:

```ruby
class Mutations::PromoteEmployee < Mutations::BaseMutation
  pundit_policy_class ::UserPolicy
  pundit_role :admin
end
```

これで、mutation は実行前に `UserPolicy#admin?` をチェックします。

より柔軟なポリシー検索については、下の [カスタムポリシーの検索](#custom-policy-lookup) を参照してください。

#### ロードされたオブジェクトの認可

mutation は `loads:` オプションを使って ID によるオブジェクトのロードと認可を自動的に行えます。

通常の [オブジェクトの読み取り権限](#authorizing-objects) に加えて、特定の mutation 入力に対して追加の role を `pundit_role:` オプションで指定できます:

```ruby
class Mutations::FireEmployee < Mutations::BaseMutation
  argument :employee_id, ID,
    loads: Types::Employee,
    pundit_role: :supervisor,
end
```

上記の例では、`EmployeePolicy#supervisor?` が true でない限り mutation は中断されます。

#### 未承認の mutation

デフォルトでは、mutation 内の認可失敗は Ruby の例外を発生させます。これをカスタマイズするには、ベース mutation に `#unauthorized_by_pundit(owner, value)` を実装してください。例えば:

```ruby
class Mutations::BaseMutation < GraphQL::Schema::RelayClassicMutation
  def unauthorized_by_pundit(owner, value)
    # No error, just return nil:
    nil
  end
end
```

このメソッドには次の引数が渡されます:

- `owner`: 役割が満たされなかった `GraphQL::Schema::Argument` か mutation クラス
- `value`: `context[:current_user]` に対してパスしなかったオブジェクト

このメソッドは mutation のインスタンスメソッドなので、メソッド内で `context` にアクセスすることもできます。

このメソッドが何を返しても、それは mutation の早期リターン値として扱われます。例えば、[データとしての errors を返す](/mutations/mutation_errors) といったことが可能です:

```ruby
class Mutations::BaseMutation < GraphQL::Schema::RelayClassicMutation
  field :errors, [String]

  def unauthorized_by_pundit(owner, value)
    # Return errors as data:
    { errors: ["Missing required permission: #{owner.pundit_role}, can't access #{value.inspect}"] }
  end
end
```

## resolver の認可

Resolver は [mutations](#authorizing-mutations) と同様に認可され、同様のセットアップが必要です:

```ruby
# app/graphql/resolvers/base_resolver.rb
class Resolvers::BaseResolver < GraphQL::Schema::Resolver
  include GraphQL::Pro::PunditIntegration::ResolverIntegration
  argument_class BaseArgument
  # pundit_role nil # to disable authorization by default
end
```

それ以外の詳細は上の [mutation の認可](#authorizing-mutations) を参照してください。

## カスタムポリシーの検索

デフォルトでは、統合は Pundit のトップレベルメソッドを使ってポリシーとやり取りします:

- ポリシーインスタンスを見つけるために `Pundit.policy!(context[:current_user], object)` を呼び出します
- `items` をフィルタするために `Pundit.policy_scope!(context[:current_user], items)` を呼び出します

### カスタムポリシーメソッド

スキーマ内で次のメソッドを定義することでカスタム検索を実装できます:

- `pundit_policy_class_for(object, context)` — ポリシークラスを返す（見つからなければエラーを投げる）
- `pundit_role_for(object, context)` — role メソッド（Symbol）を返す、または認可をバイパスするために `nil` を返す
- `scope_by_pundit_policy(context, items)` — `items` にスコープを適用する（見つからなければエラーを投げる）

オブジェクトごとにライフサイクルが異なるため、フックは少し異なる方法でインストールされます:

- ベースの argument、field、mutation クラスにはこれらの名前のインスタンスメソッドを置くべきです
- ベースの type クラスにはこれらの名前のクラスメソッドを置くべきです

以下はカスタムフックのインストール例です:

```ruby
module CustomPolicyLookup
  # Lookup policies in the `SystemAdmin::` namespace for system_admin users
  # @return [Class]
  def pundit_policy_class_for(object, context)
    current_user = context[:current_user]
    if current_user.system_admin?
      SystemAdmin.const_get("#{object.class.name}Policy")
    else
      super
    end
  end

  # Require admin permissions if the object is pending_approval
  def pundit_role_for(object, context)
    if object.pending_approval?
      :admin
    else
      super # fall back to the normally-configured role
    end
  end
end

# Add policy hooks as class methods
class Types::BaseObject < GraphQL::Schema::Object
  extend CustomPolicyLookup
end
class Types::BaseUnion < GraphQL::Schema::Union
  extend CustomPolicyLookup
end
module Types::BaseInterface
  include GraphQL::Schema::Interface
  # Add this as a class method that will be "inherited" by other interfaces:
  definition_methods do
    include CustomPolicyLookup
  end
end

# Add policy hooks as instance methods
class Types::BaseField < GraphQL::Schema::Field
  include CustomPolicyLookup
end
class Types::BaseArgument < GraphQL::Schema::Argument
  include CustomPolicyLookup
end
class Mutations::BaseMutation < GraphQL::Schema::RelayClassicMutation
  include CustomPolicyLookup
end
```

### クラスごとのポリシー

クラスごとに 1 つのポリシーを持つアプローチも良い方法です。`policy_class_for(object, context)` を実装してクラス内でポリシーを検索できます。例えば:

```ruby
class Mutations::BaseMutation < GraphQL::Schema::RelayClassicMutation
  def policy_class_for(_object, _context)
    # Look up a nested `Policy` constant:
    self.class.const_get(:Policy)
  end
end
```

その後、各 mutation が自分のポリシーをインラインで定義できます。例えば:

```ruby
class Mutations::PromoteEmployee < Mutations::BaseMutation
  # This will be found by `BaseMutation.policy_class`, defined above:
  class Policy
    # ...
  end

  pundit_role :admin
end
```

これで、`Mutations::PromoteEmployee::Policy#admin?` が mutation 実行前にチェックされます。

## カスタムユーザーの取得

デフォルトでは、Pundit 統合は `context[:current_user]` で current user を探します。`#pundit_user` をカスタムクエリコンテキストクラス上で実装することでこれを上書きできます。例えば:

```ruby
# app/graphql/query_context.rb
class QueryContext < GraphQL::Query::Context
  def pundit_user
    # Lookup `context[:viewer]` instead:
    self[:viewer]
  end
end
```

その後、スキーマでカスタムクラスを接続してください:

```ruby
class MySchema < GraphQL::Schema
  context_class(QueryContext)
end
```

これで Pundit 統合は実行時にあなたの `def pundit_user` を使って current user を取得します。
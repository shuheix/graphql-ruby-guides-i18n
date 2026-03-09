---
title: Mutation の認可
description: mutation の権限チェック
sidebar:
  order: 3
---
Mutation を実行する前に、一般的に以下のことを行いたいでしょう:

- 現在のユーザーがこの Mutation を実行する権限を持っているか確認する
- いくつかの `ID` 入力を使ってデータベースからオブジェクトを読み込む
- 読み込んだオブジェクトをユーザーが変更する権限があるか確認する

このガイドでは、GraphQL-Ruby を使ってそのワークフローを実現する方法を説明します。

## Mutation をインスタンス化する前の条件の確認

```ruby
class UpdateUserMutation < BaseMutation
  # ...

  def resolve(update_user_input:, user:)
    # ...
  end

  def self.authorized?(obj, ctx)
    super && ctx[:viewer].present?
  end
end
```

## ユーザーの権限を確認する

データベースからいかなるデータも読み込む前に、ユーザーが特定の権限レベルを持っているか確認したい場合があります。例えば、` .admin?` ユーザーだけが `Mutation.promoteEmployee` を実行できる、というケースです。

このチェックは Mutation の `#ready?` メソッドで実装できます:

```ruby
class Mutations::PromoteEmployee < Mutations::BaseMutation
  def ready?(**args)
    # Called with mutation args.
    # Use keyword args such as employee_id: or **args to collect them
    if !context[:current_user].admin?
      raise GraphQL::ExecutionError, "Only admins can run this mutation"
    else
      # Return true to continue the mutation:
      true
    end
  end

  # ...
end
```

これにより、非 `admin` ユーザーがこの Mutation を実行しようとすると、実行されず、代わりにレスポンスにエラーが返されます。

さらに、`#ready?` は `false, { ... }` を返すことで、[エラーをデータとして返す](/mutations/mutation_errors.html#errors-as-data) ことができます:

```ruby
def ready?
  if !context[:current_user].allowed?
    return false, { errors: ["You don't have permission to do this"]}
  else
    true
  end
end
```

## オブジェクトの読み込みと認可

多くの場合、Mutation は `ID` を入力として受け取り、それらを使ってデータベースからレコードを読み込みます。`loads:` オプションを指定すると、GraphQL-Ruby が ID の読み込みを代わりに行えます。

簡単な例は次のとおりです:

```ruby
class Mutations::PromoteEmployee < Mutations::BaseMutation
  # `employeeId` is an ID, Types::Employee is an _Object_ type
  argument :employee_id, ID, loads: Types::Employee

  # Behind the scenes, `:employee_id` is used to fetch an object from the database,
  # then the object is authorized with `Employee.authorized?`, then
  # if all is well, the object is injected here:
  def resolve(employee:)
    employee.promote!
  end
end
```

仕組みは次の通りです。`loads:` オプションを指定すると、以下のことを行います:

- 名前から `_id` を自動的に取り除き、その名前を `as:` オプションに渡す
- 指定された `ID` でオブジェクトを取得する prepare フックを追加する（[`Schema.object_from_id`](https://graphql-ruby.org/api-doc/Schema.object_from_id) を使用）
- 取得したオブジェクトの type が `loads:` に指定した type と一致するか確認する（[`Schema.resolve_type`](https://graphql-ruby.org/api-doc/Schema.resolve_type) を使用）
- 取得したオブジェクトをその type の `.authorized?` フックで実行する（詳細は [認可](/authorization/authorization) を参照）
- オブジェクト名（`employee:`）として `#resolve` に注入する

この場合、`object_from_id` が値を返さないと、Mutation はエラーで失敗します。

あるいは、あなたの `ID` がクラスと id の両方を指定していない場合、resolvers は `load_#{argument}` メソッドを持っており、これをオーバーライドできます。

```ruby
argument :employee_id, ID, loads: Types::Employee

def load_employee(id)
  ::Employee.find(id)
end
```

この動作を望まない場合は、使用しないでください。代わりに引数を `ID` 型として定義し、自分で処理してください。例えば:

```ruby
# No special loading behavior:
argument :employee_id, ID
```

## このユーザーはこの操作を実行できますか？

場合によっては、特定のユーザー・オブジェクト・操作の組み合わせを認可する必要があります。例えば、`.admin?` ユーザーは全ての従業員を昇進させられるわけではありません。自分が管理している従業員だけ昇進させることができます。

このチェックは `#authorized?` メソッドを実装して追加できます。例えば:

```ruby
def authorized?(employee:)
  super && context[:current_user].manager_of?(employee)
end
```

`#authorized?` が `false`（または偽値）を返すと Mutation は中止されます。`true`（または真値）を返すと Mutation は継続します。

#### エラーの追加

データとしてエラーを追加するには（[Mutation のエラー](/mutations/mutation_errors.html#errors-as-data) に説明されているように）、`false` とともに値を返します。例えば:

```ruby
def authorized?(employee:)
  super && if context[:current_user].manager_of?(employee)
    true
  else
    return false, { errors: ["Can't promote an employee you don't manage"] }
  end
end
```

あるいは、トップレベルのエラーを追加するには、`GraphQL::ExecutionError` を発生させます。例えば:

```ruby
def authorized?(employee:)
  super && if context[:current_user].manager_of?(employee)
    true
  else
    raise GraphQL::ExecutionError, "You can only promote your _own_ employees"
  end
end
```

どちらの場合でも（`[false, data]` を返すかエラーを発生させるか）、Mutation は中止されます。

## 最後に処理を行う

一般的な権限確認が済み、データが読み込まれ、オブジェクトの検証が完了したので、`#resolve` を使ってデータベースを変更できます:

```ruby
def resolve(employee:)
  if employee.promote
    {
      employee: employee,
      errors: [],
    }
  else
    # See "Mutation Errors" for more:
    {
      errors: employee.errors.full_messages
    }
  end
end
```